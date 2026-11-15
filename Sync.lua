-- XbiGold : partage des prix entre joueurs de la guilde et du groupe qui ont l'addon
--
-- Messages (préfixe "XbiGold", séparateur ";") :
--   H;proto;marché;dernierScan;nbObjets       présence (connexion, groupe, après un scan)
--   R;proto;marché;depuis                     "envoyez-moi ce qui est plus récent que depuis"
--   O;proto;marché;fraîcheur                  "je réponds" (les autres n'envoient pas en double)
--   D;id;n°;total;morceau                     un bloc de données compressé (Deflate + Base64)
-- Un bloc = ~250 objets, autonome : si un message se perd, seul ce bloc est perdu.
local _, XG = ...

local floor, max, min, random, abs = math.floor, math.max, math.min, math.random, math.abs
local PREFIX, PROTO = "XbiGold", "1"
local CHUNK = 228          -- taille d'un morceau (le message entier doit rester sous 255)
local PER_BLOCK = 250      -- objets par bloc
local MAX_FULL = 2500      -- objets maximum par envoi (~3 min)
local MIN_VALUE = 50       -- on ne partage pas les objets à moins de 50 pc
local SEND_EVERY = 1.1     -- secondes entre deux messages (limite du jeu par préfixe)

local Enc = C_EncodingUtil
local log10 = math.log10 or function(x) return math.log(x) / math.log(10) end
local queue, partial = {}, {}
local pendingReply
local lastHello, lastRequest = 0, 0
XG.peers = {}

local function enabled()
    return XG.S and XG.S.share and Enc and Enc.CompressString and C_ChatInfo and C_ChatInfo.SendAddonMessage
end

local function me() return UnitName("player") end

local function short(sender)
    if Ambiguate then return Ambiguate(sender, "none") end
    return (sender:match("^([^%-]+)")) or sender
end

-- Canaux où envoyer : la guilde, et le groupe s'il contient des joueurs hors de la guilde
local function channels()
    local out = {}
    if IsInGuild and IsInGuild() then out[#out + 1] = "GUILD" end
    if XG.S.shareGroup and IsInGroup and IsInGroup() then
        local ch = (LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT"
            or (IsInRaid() and "RAID" or "PARTY")
        local outsider = not (IsInGuild and IsInGuild())
        if not outsider then
            local n = GetNumGroupMembers() or 0
            local prefix = IsInRaid() and "raid" or "party"
            for i = 1, n do
                local u = prefix .. i
                if UnitExists(u) and not UnitIsUnit(u, "player") and not UnitIsInMyGuild(u) then outsider = true break end
            end
        end
        if outsider then out[#out + 1] = ch end
    end
    return out
end

------------------------------------------------------------------------
-- Envoi (file d'attente qui respecte la limite du jeu)
------------------------------------------------------------------------
local function enqueue(channel, msg)
    queue[#queue + 1] = {channel, msg}
end

local SUCCESS = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
local THROTTLED = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.AddonMessageThrottle or 3
local waitUntil = 0
C_Timer.NewTicker(SEND_EVERY, function()
    if #queue == 0 or GetTime() < waitUntil then return end
    local item = queue[1]
    local ok, r = pcall(C_ChatInfo.SendAddonMessage, PREFIX, item[2], item[1])
    if ok and (r == nil or r == true or r == SUCCESS) then
        table.remove(queue, 1)
    elseif ok and (r == THROTTLED or (Enum and Enum.SendAddonMessageResult and r == Enum.SendAddonMessageResult.ChannelThrottle)) then
        waitUntil = GetTime() + 3 -- le jeu nous freine : on patiente
    else
        table.remove(queue, 1) -- plus dans le groupe, etc. : on abandonne ce message
    end
end)

function XG:SyncQueueSize() return #queue end

local function broadcast(msg, onlyChannel)
    if onlyChannel then enqueue(onlyChannel, msg) return end
    for _, ch in ipairs(channels()) do enqueue(ch, msg) end
end

------------------------------------------------------------------------
-- Encodage des données
------------------------------------------------------------------------
-- 3 chiffres significatifs : assez précis pour des prix, et ça se compresse bien
local function sig3(v)
    v = floor(v or 0)
    if v < 1000 then return v end
    local e = 10 ^ (floor(log10(v)) - 2)
    return floor(floor(v / e + 0.5) * e + 0.5)
end

local blockCounter = 0
local function newId()
    blockCounter = blockCounter + 1
    local chars = "0123456789abcdefghijklmnopqrstuvwxyz"
    local s = ""
    for _ = 1, 3 do local i = random(1, 36) s = s .. chars:sub(i, i) end
    return s .. (blockCounter % 36)
end

-- entries : liste de {key, it} ; envoie en blocs indépendants
local function sendEntries(market, entries, onlyChannel)
    local base = time()
    for start = 1, #entries, PER_BLOCK do
        local lines = {PROTO .. ";" .. market .. ";" .. base}
        for i = start, min(#entries, start + PER_BLOCK - 1) do
            local key, it = entries[i][1], entries[i][2]
            local h = entries[i][3]
            lines[#lines + 1] = table.concat({key, sig3(it.m), sig3(it.l), it.q or 0, floor((it.sr or 0) * 10 + 0.5),
                max(0, floor((base - (it.t or base)) / 60)), h and sig3(h) or 0}, ",")
        end
        local raw = table.concat(lines, "\n")
        local ok, packed = pcall(Enc.CompressString, raw, 0, 2)
        if ok and packed then
            local b64 = Enc.EncodeBase64(packed, 0)
            local n = math.ceil(#b64 / CHUNK)
            local id = newId()
            for seq = 1, n do
                broadcast("D;" .. id .. ";" .. seq .. ";" .. n .. ";" .. b64:sub((seq - 1) * CHUNK + 1, seq * CHUNK), onlyChannel)
            end
        end
    end
end

local function marketTable(key)
    local db = XG.db
    db.markets[key] = db.markets[key] or {items = {}, lastScan = 0, scans = 0, deals = {}}
    local M = db.markets[key]
    M.items = M.items or {}
    return M
end

local function acceptedMarket(key)
    return key == XG:MarketKey(false) or key == XG:MarketKey(true)
end

-- Fraîcheur des données d'un marché : le plus récent de notre scan et de ce qu'on a reçu
function XG:Freshness(M)
    M = M or XG.M
    return max(M.lastScan or 0, M.shared and M.shared.t or 0)
end

------------------------------------------------------------------------
-- Réception
------------------------------------------------------------------------
local function localMedian(it)
    if not it or not it.d then return nil, 0 end
    local today, vals = XG.Today(), {}
    for day, v in pairs(it.d) do if today - day <= 7 then vals[#vals + 1] = v end end
    if #vals == 0 then return nil, 0 end
    return XG.Median(vals), #vals
end

local function mergePoint(M, key, m, l, q, s, t, h)
    if m <= 0 then return "skip" end
    local it = M.items[key]
    local ref, nd = localMedian(it)
    -- garde-fou : une valeur absurde par rapport à notre historique est ignorée
    if ref and nd >= 2 and (m > ref * 6 or m < ref / 6) then return "reject" end
    if not it then
        it = {d = {}, v = {}}
        M.items[key] = it
    end
    if s and s > 0 then
        it.sr = it.sr and floor((it.sr * 0.5 + s * 0.5) * 10 + 0.5) / 10 or s
        it.srn = max(it.srn or 0, 1)
    end
    if t <= (it.t or 0) then return "old" end
    local day = floor(t / 86400)
    -- amorce l'historique d'un nouveau joueur avec la médiane 7 jours de l'expéditeur
    if h and h > 0 then
        local hasPast = false
        for d in pairs(it.d) do if d < day then hasPast = true break end end
        if not hasPast then it.d[day - 1] = h end
    end
    if it.d[day] and it.dday == day then
        it.dn = (it.dn or 1) + 1
        it.d[day] = floor(it.d[day] + (m - it.d[day]) / it.dn)
    else
        it.d[day] = m
        it.dn, it.dday = 1, day
    end
    it.v[day] = max(it.v[day] or 0, q)
    it.dl = it.dl or {}
    it.dl[day] = it.dl[day] and min(it.dl[day], l) or l
    it.m, it.l, it.q, it.t = m, l, q, t
    XG:UpdateHourProfile(it, t, l, q, XG.WeekRef(it), M)
    return "ok"
end

local function onBlock(sender, raw)
    local okD, bin = pcall(Enc.DecodeBase64, raw, 0)
    if not okD or not bin then return end
    local okZ, text = pcall(Enc.DecompressString, bin, 0)
    if not okZ or not text or #text > 400000 then return end
    local header, body = text:match("^([^\n]*)\n?(.*)$")
    local proto, market, base = (header or ""):match("^([^;]+);([^;]+);(%d+)$")
    if proto ~= PROTO or not acceptedMarket(market) then return end
    base = tonumber(base)
    if not base or base > time() + 600 then return end
    local M = marketTable(market)
    local okN, rej, newest = 0, 0, 0
    for line in body:gmatch("[^\n]+") do
        local key, m, l, q, s, dt, h = line:match("^([%d:%-]+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)$")
        if key then
            local t = base - tonumber(dt) * 60
            local r = mergePoint(M, key, tonumber(m), tonumber(l), tonumber(q), tonumber(s) / 10, t, tonumber(h))
            if r == "ok" then okN = okN + 1; newest = max(newest, t) elseif r == "reject" then rej = rej + 1 end
        end
    end
    local p = XG.peers[sender] or {}
    p.received = (p.received or 0) + okN
    p.rejected = (p.rejected or 0) + rej
    p.seen = time()
    XG.peers[sender] = p
    if okN > 0 then
        M.shared = M.shared or {}
        if newest > (M.shared.t or 0) then M.shared.t, M.shared.from = newest, sender end
        M.shared.count = (M.shared.count or 0) + okN
        if XG.RefreshUI then XG:RefreshUI() end
    end
end

local function onData(sender, id, seq, n, chunk)
    seq, n = tonumber(seq), tonumber(n)
    if not seq or not n or n > 200 or seq < 1 or seq > n then return end
    local k = sender .. id
    local p = partial[k]
    if not p then
        p = {n = n, got = 0, parts = {}, t = GetTime()}
        partial[k] = p
    end
    if not p.parts[seq] then
        p.parts[seq] = chunk
        p.got = p.got + 1
        p.t = GetTime()
    end
    if p.got >= p.n then
        partial[k] = nil
        pcall(onBlock, sender, table.concat(p.parts))
    end
end

-- nettoie les blocs incomplets
C_Timer.NewTicker(30, function()
    local now = GetTime()
    for k, p in pairs(partial) do if now - p.t > 120 then partial[k] = nil end end
end)

------------------------------------------------------------------------
-- Ce qu'on envoie
------------------------------------------------------------------------
-- Réponse à une demande : tout ce qui est plus récent que "since" (les plus récents d'abord)
local function sendSince(since, channel)
    local M, market = XG.M, XG:MarketKey(XG.neutral)
    local list = {}
    for key, it in pairs(M.items) do
        if it.t and it.t > since and it.m and it.m >= MIN_VALUE then
            local h, nd = localMedian(it)
            list[#list + 1] = {key, it, nd >= 2 and h or nil}
        end
    end
    table.sort(list, function(a, b) return a[2].t > b[2].t end)
    while #list > MAX_FULL do table.remove(list) end
    if #list > 0 then sendEntries(market, list, channel) end
    return #list
end

local function hello(channel)
    if not enabled() then return end
    local M = XG.M
    broadcast(("H;%s;%s;%d;%d"):format(PROTO, XG:MarketKey(XG.neutral), XG:Freshness(M), XG:CountItems()), channel)
end

-- Demande à la guilde et au groupe ce qu'ils ont de plus récent
function XG:SyncRequest()
    if not enabled() then return end
    lastRequest = time()
    broadcast(("R;%s;%s;%d"):format(PROTO, XG:MarketKey(XG.neutral), XG:Freshness(XG.M)))
end

-- Après notre scan : on envoie ce qui a changé depuis le dernier envoi
function XG:Sync_AfterScan(scanTime)
    if not enabled() then return end
    hello()
    local M, market = XG.M, XG:MarketKey(XG.neutral)
    local list = {}
    for key, it in pairs(M.items) do
        if it.t == scanTime and it.m and it.m >= MIN_VALUE then
            local changed = not it.sm or abs(it.m - it.sm) > it.sm * 0.03
                or abs((it.q or 0) - (it.sq or 0)) > max(3, (it.sq or 0) * 0.1)
                or (scanTime - (it.st or 0)) > 6 * 3600
            if changed then
                local h, nd = localMedian(it)
                list[#list + 1] = {key, it, nd >= 2 and h or nil}
            end
        end
    end
    if #list == 0 or #channels() == 0 then return end
    -- les objets qui ont le plus de valeur d'abord ; le reste partira au prochain scan
    table.sort(list, function(a, b) return a[2].m * math.sqrt((a[2].q or 0) + 1) > b[2].m * math.sqrt((b[2].q or 0) + 1) end)
    while #list > MAX_FULL do table.remove(list) end
    for _, e in ipairs(list) do
        local it = e[2]
        it.sm, it.sq, it.st = it.m, it.q or 0, scanTime
    end
    sendEntries(market, list)
end

------------------------------------------------------------------------
-- Événements
------------------------------------------------------------------------
local f = CreateFrame("Frame")
XG.Reg(f, "PLAYER_LOGIN", "CHAT_MSG_ADDON", "GROUP_JOINED", "GROUP_ROSTER_UPDATE")
f:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
        -- on laisse le temps à la guilde de se charger
        C_Timer.After(20, function() if enabled() then hello(); XG:SyncRequest() end end)
        return
    end
    if not XG.M or not enabled() then return end
    if event == "GROUP_JOINED" or event == "GROUP_ROSTER_UPDATE" then
        if XG.S.shareGroup and time() - lastHello > 300 and IsInGroup() then
            lastHello = time()
            C_Timer.After(5, function()
                for _, ch in ipairs(channels()) do
                    if ch ~= "GUILD" then hello(ch); broadcast(("R;%s;%s;%d"):format(PROTO, XG:MarketKey(XG.neutral), XG:Freshness(XG.M)), ch) end
                end
            end)
        end
        return
    end
    -- CHAT_MSG_ADDON
    if prefix ~= PREFIX or not msg or not sender then return end
    sender = short(sender)
    if sender == me() then return end
    if channel ~= "GUILD" and not XG.S.shareGroup then return end
    local kind = msg:sub(1, 1)
    if kind == "D" then
        local id, seq, n, chunk = msg:match("^D;([^;]+);(%d+);(%d+);(.+)$")
        if id then onData(sender, id, seq, n, chunk) end
    elseif kind == "H" then
        local proto, market, fresh, count = msg:match("^H;([^;]+);([^;]+);(%d+);(%d+)$")
        if proto then
            local p = XG.peers[sender] or {}
            p.market, p.fresh, p.count, p.channel, p.seen, p.proto = market, tonumber(fresh), tonumber(count), channel, time(), proto
            p.sameMarket = acceptedMarket(market)
            XG.peers[sender] = p
            if XG.RefreshUI then XG:RefreshUI() end
        end
    elseif kind == "R" then
        local proto, market, since = msg:match("^R;([^;]+);([^;]+);(%d+)$")
        since = tonumber(since)
        if proto ~= PROTO or market ~= XG:MarketKey(XG.neutral) or not since then return end
        local mine = XG:Freshness(XG.M)
        if mine < since + 900 or #queue > 60 then return end -- on n'a rien de plus récent (15 min)
        -- on attend un peu : si quelqu'un d'autre de plus à jour répond, on se tait
        local token = {}
        pendingReply = {token = token, fresh = mine, market = market}
        C_Timer.After(2 + random() * 6, function()
            if pendingReply and pendingReply.token == token then
                pendingReply = nil
                broadcast(("O;%s;%s;%d"):format(PROTO, market, mine), channel)
                sendSince(since, channel)
            end
        end)
    elseif kind == "O" then
        local proto, market, fresh = msg:match("^O;([^;]+);([^;]+);(%d+)$")
        if pendingReply and market == pendingReply.market and tonumber(fresh or 0) >= pendingReply.fresh - 300 then
            pendingReply = nil -- un autre s'en charge
        end
    end
end)
