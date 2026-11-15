-- XbiGold : stockage des prix (par marché = type de royaume + faction), historique journalier
local _, XG = ...

local floor, max, min = math.floor, math.max, math.min
local HISTORY_DAYS = 21

XG.DEFAULTS = {
    minimap = true, minimapAngle = 200,
    tooltip = true, tooltipShift = false,
    autoScan = true,          -- scan complet automatique à l'ouverture de l'HV (si 15 min écoulées)
    openWithAH = true,        -- ouvrir la fenêtre à côté de l'HV
    minProfit = 5000,         -- profit minimum d'une affaire (50 pa)
    minMargin = 0.25,         -- marge minimum (25 %)
    dealAlert = true,         -- son + message quand une grosse affaire est trouvée
    merchantOverlay = true,   -- bénéfice affiché sur les objets des marchands
    sessionHUD = true,
    scale = 1,
    share = true,             -- partager les prix avec la guilde
    shareGroup = true,        -- ... et avec le groupe
    fastOnly = false,         -- bonnes affaires : seulement ce qui se revend vite
}

-- Marché : sur Forever l'HV est commun à toute la région, par type de royaume (Normal, PvP, RP...) et faction
function XG:MarketKey(neutral)
    local realm = GetRealmName() or "?"
    if neutral then return realm .. " - Neutre" end
    local faction = UnitFactionGroup("player") or "Neutral"
    return realm .. " - " .. faction
end

-- HV neutres (Gadgetzan, Baie-du-Butin, Long-guet) : annonces à part et commission de 15 %
XG.NEUTRAL_AH_MAPS = {[1446] = true, [1434] = true, [1452] = true}
function XG:SelectMarket(neutral)
    local mk = XG:MarketKey(neutral)
    local db = XG.db
    db.markets[mk] = db.markets[mk] or {items = {}, lastScan = 0, scans = 0, deals = {}}
    XG.M = db.markets[mk]
    XG.M.items = XG.M.items or {}
    XG.M.snap = XG.M.snap or {}
    XG.M.deals = XG.M.deals or {}
    XG.neutral = neutral and true or false
    XG.AH_CUT = neutral and 0.15 or 0.05
end

function XG:AtNeutralAH()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    return map and XG.NEUTRAL_AH_MAPS[map] or false
end

function XG:InitDB()
    XbiGoldDB = XbiGoldDB or {}
    XbiGoldCharDB = XbiGoldCharDB or {}
    local db = XbiGoldDB
    db.settings = db.settings or {}
    for k, v in pairs(XG.DEFAULTS) do
        if db.settings[k] == nil then db.settings[k] = v end
    end
    db.markets = db.markets or {}
    db.vendors = db.vendors or {}     -- objets vus chez les marchands (prix identiques partout)
    db.sessions = db.sessions or {}
    db.version = 1
    XG.db, XG.cdb, XG.S = db, XbiGoldCharDB, db.settings

    XG:SelectMarket(false)
    XG:PruneHistory()
end

-- Supprime les jours trop anciens
function XG:PruneHistory()
    local cutoff = XG.Today() - HISTORY_DAYS
    for _, market in pairs(XG.db.markets) do for _, it in pairs(market.items or {}) do
        if it.d then for day in pairs(it.d) do if day < cutoff then it.d[day] = nil end end end
        if it.v then for day in pairs(it.v) do if day < cutoff then it.v[day] = nil end end end
        if it.dl then for day in pairs(it.dl) do if day < cutoff then it.dl[day] = nil end end end
    end end
end

function XG:Item(key)
    return XG.M.items[tostring(key)]
end

-- Enregistre le résultat d'un scan pour un objet
-- mkt = valeur marché du jour, low = prix le plus bas, qty = quantité en vente, n = nombre d'annonces
function XG:RecordScan(key, mkt, low, qty, n, now)
    key = tostring(key)
    local it = XG.M.items[key]
    if not it then
        it = {d = {}, v = {}}
        XG.M.items[key] = it
    end
    local day = XG.Today()
    -- Moyenne des scans d'une même journée
    local prev = it.d[day]
    if prev and it.dn and it.dday == day then
        it.dn = it.dn + 1
        it.d[day] = floor(prev + (mkt - prev) / it.dn)
    else
        it.d[day] = floor(mkt)
        it.dn, it.dday = 1, day
    end
    it.v[day] = max(it.v[day] or 0, qty)
    it.dl = it.dl or {}
    it.dl[day] = it.dl[day] and min(it.dl[day], floor(low)) or floor(low)
    it.m, it.l, it.q, it.n, it.t = floor(mkt), floor(low), qty, n, now
    XG:UpdateHourProfile(it, now, low, qty, XG.WeekRef(it))
end

-- Référence stable pour le profil horaire : médiane des 7 derniers jours
function XG.WeekRef(it)
    local today, vals = XG.Today(), {}
    for d, v in pairs(it.d or {}) do if today - d <= 7 then vals[#vals + 1] = v end end
    return XG.Median(vals)
end

------------------------------------------------------------------------
-- Profil horaire : prix et nombre d'annonces selon l'heure de la journée
-- it.hr = 24 cases "prix:quantité:échantillons" (prix = prix le plus bas / valeur du jour x 1000)
------------------------------------------------------------------------
local HR_MIN_VALUE = 100 -- seulement pour les objets à partir de 1 pa (taille des sauvegardes)

function XG.DecodeHours(s)
    local p, q, n = {}, {}, {}
    local h = 0
    for slot in ((s or "") .. ","):gmatch("([^,]*),") do
        local a, b, c = slot:match("^(%d+):(%d+):(%d+)$")
        p[h], q[h], n[h] = tonumber(a), tonumber(b), tonumber(c) or 0
        h = h + 1
        if h > 23 then break end
    end
    for i = h, 23 do n[i] = 0 end
    return p, q, n
end

local function encodeHours(p, q, n)
    local out = {}
    for h = 0, 23 do
        out[h + 1] = (n[h] or 0) > 0 and (floor(p[h] + 0.5) .. ":" .. floor(q[h] + 0.5) .. ":" .. n[h]) or ""
    end
    return table.concat(out, ",")
end

local function hourOf(t)
    return tonumber(date("%H", t)) or 0
end
XG.HourOf = hourOf

function XG:UpdateHourProfile(it, t, low, qty, dayMkt, M)
    if not dayMkt or dayMkt < HR_MIN_VALUE or not low or low <= 0 then return end
    local h = hourOf(t)
    local p, q, n = XG.DecodeHours(it.hr)
    local ratio = XG.Clamp(low / dayMkt, 0.2, 5) * 1000
    local k = n[h] or 0
    local w = 1 / min(k + 1, 10) -- moyenne glissante sur ~10 passages
    p[h] = p[h] and (p[h] + (ratio - p[h]) * w) or ratio
    q[h] = q[h] and (q[h] + ((qty or 0) - q[h]) * w) or (qty or 0)
    n[h] = min(k + 1, 99)
    it.hr = encodeHours(p, q, n)
    -- profil général du marché (tous objets confondus)
    M = M or XG.M
    M.hourAll = M.hourAll or {p = {}, n = {}}
    local hp, hn = M.hourAll.p, M.hourAll.n
    local hk = hn[h] or 0
    local hw = 1 / min(hk + 1, 2000)
    hp[h] = hp[h] and (hp[h] + (ratio - hp[h]) * hw) or ratio
    hn[h] = hk + 1
end

-- Meilleures heures pour vendre un objet : prix au-dessus de la moyenne, moins d'annonces
-- Renvoie une liste de 24 {h, prix relatif, quantité relative, échantillons}, et le nombre d'heures connues
function XG:HourStats(key)
    local it = XG:Item(key)
    if not it or not it.hr then return nil, 0 end
    local p, q, n = XG.DecodeHours(it.hr)
    local sp, sq, cnt = 0, 0, 0
    for h = 0, 23 do if (n[h] or 0) > 0 and p[h] then sp, sq, cnt = sp + p[h], sq + q[h], cnt + 1 end end
    if cnt == 0 then return nil, 0 end
    local ap, aq = sp / cnt, sq / cnt
    local out = {}
    for h = 0, 23 do
        if (n[h] or 0) > 0 and p[h] then
            out[h] = {h = h, price = p[h] / ap - 1, qty = aq > 0 and (q[h] / aq - 1) or 0, n = n[h]}
        end
    end
    return out, cnt
end

-- Marque comme absent de l'HV (vu lors d'un scan complet sans annonce)
function XG:RecordAbsent(key, now)
    local it = XG.M.items[key]
    if it and it.t and it.t < now then
        it.q, it.n = 0, 0
    end
end

------------------------------------------------------------------------
-- Lecture des prix
------------------------------------------------------------------------

-- Valeurs journalières triées du plus récent au plus ancien : {day, mkt}
local function days(it, maxDays)
    local out = {}
    if not it or not it.d then return out end
    local today = XG.Today()
    for day, v in pairs(it.d) do
        if today - day < (maxDays or HISTORY_DAYS) then out[#out + 1] = {day, v} end
    end
    table.sort(out, function(a, b) return a[1] > b[1] end)
    return out
end
XG.Days = days

-- Valeur marché de référence : médiane des 7 derniers jours (résiste aux manipulations)
function XG:MarketValue(key)
    local it = XG:Item(key)
    if not it then return nil, 0 end
    local d = days(it, 7)
    if #d == 0 then return it.m, 0 end
    local vals = {}
    for i = 1, #d do vals[i] = d[i][2] end
    return floor(XG.Median(vals)), #d
end

-- Référence "hier et avant" (sans le jour courant), pour juger un prix d'aujourd'hui
function XG:PastValue(key)
    local it = XG:Item(key)
    if not it then return nil, 0 end
    local today = XG.Today()
    local vals = {}
    for day, v in pairs(it.d) do
        if day < today and today - day <= 7 then vals[#vals + 1] = v end
    end
    if #vals == 0 then return nil, 0 end
    return floor(XG.Median(vals)), #vals
end

-- Tendance : prix récent (2 j) comparé aux jours d'avant (7 j)
function XG:Trend(key)
    local it = XG:Item(key)
    local d = days(it, 9)
    if #d < 3 then return nil end
    local recent = {d[1][2], d[2] and d[2][2]}
    local old = {}
    for i = 3, #d do old[#old + 1] = d[i][2] end
    local r, o = XG.Median(recent), XG.Median(old)
    if not r or not o or o == 0 then return nil end
    return r / o - 1
end

-- Autres sources si XbiGold n'a pas encore vu l'objet (Auctionator, TSM)
local function external(id)
    if TSM_API and TSM_API.GetCustomPriceValue then
        local ok, v = pcall(TSM_API.GetCustomPriceValue, "DBMarket", "i:" .. id)
        if ok and v and v > 0 then return v, "TSM" end
    end
    if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID then
        local ok, v = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "XbiGold", id)
        if ok and v and v > 0 then return v, "Auctionator" end
    end
    return nil
end

-- Valeur d'un objet pour l'affichage (marché XbiGold, sinon autres addons)
function XG:Value(key)
    local v, n = XG:MarketValue(key)
    if v and v > 0 then return v, "XbiGold", n end
    local id = XG.IDFromKey(key)
    if id and tostring(key) ~= tostring(id) then
        v, n = XG:MarketValue(id)
        if v and v > 0 then return v, "XbiGold", n end
    end
    if id then
        local e, src = external(id)
        if e then return e, src, 0 end
    end
    return nil
end

-- Ventes estimées par jour (voir Scanner : disparitions d'annonces entre deux scans)
function XG:SalesPerDay(key)
    local it = XG:Item(key)
    if it and it.sr and (it.srn or 0) > 0 then return it.sr, it.srn end
    local id = XG.IDFromKey(key)
    if TSM_API and TSM_API.GetCustomPriceValue and id then
        local ok, v = pcall(TSM_API.GetCustomPriceValue, "DBRegionSoldPerDay*100", "i:" .. id)
        if ok and v and v > 0 then return v / 100, -1 end
    end
    return nil
end

function XG:CountItems()
    local n = 0
    for _ in pairs(XG.M.items) do n = n + 1 end
    return n
end
