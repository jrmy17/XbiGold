-- XbiGold : session de farm (butin + or ramassé, valeur, po/heure, par zone)
local _, XG = ...

local floor, max = math.floor, math.max

-- Motifs des messages de butin, construits depuis les textes du jeu (marche dans toutes les langues)
local function toPattern(s)
    if not s then return nil end
    s = s:gsub("%%%d%$", "%%")
    s = s:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    s = s:gsub("%%s", "(.+)")
    s = s:gsub("%%d", "(%%d+)")
    return "^" .. s .. "$"
end
local MULTI = {toPattern(LOOT_ITEM_SELF_MULTIPLE), toPattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE)}
local SINGLE = {toPattern(LOOT_ITEM_SELF), toPattern(LOOT_ITEM_PUSHED_SELF)}

-- Fenêtres où l'argent gagné/dépensé ne vient pas du farm
local busy = {}
local BUSY_EVENTS = {
    MERCHANT_SHOW = "merchant", MERCHANT_CLOSED = "merchant",
    AUCTION_HOUSE_SHOW = "ah", AUCTION_HOUSE_CLOSED = "ah",
    MAIL_SHOW = "mail", MAIL_CLOSED = "mail",
    TRADE_SHOW = "trade", TRADE_CLOSED = "trade",
    TAXIMAP_OPENED = "taxi", TAXIMAP_CLOSED = "taxi",
    TRAINER_SHOW = "trainer", TRAINER_CLOSED = "trainer",
    GUILDBANKFRAME_OPENED = "gbank", GUILDBANKFRAME_CLOSED = "gbank",
}

local function S() return XG.cdb.session end

function XG:SessionRunning()
    local s = S()
    return s and s.running
end

function XG:SessionElapsed()
    local s = S()
    if not s then return 0 end
    local e = s.elapsed or 0
    if s.running and s.resumedAt then e = e + (GetTime() - s.resumedAt) end
    return e
end

-- Valeur unitaire d'un objet ramassé : HV (net de la commission) ou marchand, le meilleur des deux
function XG:LootValue(id)
    local info = XG.ItemInfo(id)
    local sell = info and info.sell or 0
    if info and info.bind == 1 then return sell, "marchand" end
    local v = XG:Value(id)
    if v and v * (1 - XG.AH_CUT) > sell then return floor(v * (1 - XG.AH_CUT)), "hv" end
    return sell, "marchand"
end

function XG:SessionTotals()
    local s = S()
    if not s then return 0, 0, 0 end
    local itemsValue = 0
    for id, n in pairs(s.items) do itemsValue = itemsValue + (XG:LootValue(id) or 0) * n end
    local total = itemsValue + (s.money or 0)
    local el = XG:SessionElapsed()
    local gph = el > 60 and total / el * 3600 or 0
    return total, gph, itemsValue
end

function XG:StartSession()
    local s = S()
    if s and s.running then return end
    if s and not s.running and (s.elapsed or 0) > 0 then
        -- reprise après une pause
        s.running, s.resumedAt = true, GetTime()
    else
        XG.cdb.session = {start = time(), elapsed = 0, running = true, resumedAt = GetTime(), money = 0, items = {}, zones = {}}
    end
    XG.lastMoney = GetMoney()
    XG.Print("session de farm démarrée. Bon farm !")
    XG:UpdateHUD()
end

function XG:PauseSession()
    local s = S()
    if not s or not s.running then return end
    s.elapsed = XG:SessionElapsed()
    s.running, s.resumedAt = false, nil
    XG:UpdateHUD()
end

function XG:StopSession()
    local s = S()
    if not s then return end
    if s.running then XG:PauseSession() end
    local total, gph, itemsValue = XG:SessionTotals()
    if (s.elapsed or 0) >= 60 then
        local zone, best = "?", 0
        for z, sec in pairs(s.zones) do if sec > best then zone, best = z, sec end end
        local top = {}
        for id, n in pairs(s.items) do top[#top + 1] = {id, n, (XG:LootValue(id) or 0) * n} end
        table.sort(top, function(a, b) return a[3] > b[3] end)
        while #top > 8 do table.remove(top) end
        table.insert(XG.db.sessions, 1, {t = s.start, dur = floor(s.elapsed), money = s.money, value = floor(itemsValue),
            gph = floor(gph), zone = zone, top = top, char = UnitName("player"), level = UnitLevel("player")})
        while #XG.db.sessions > 60 do table.remove(XG.db.sessions) end
        XG.Print(("session terminée : %s en %s, soit %s/heure (%s)."):format(XG.Money(total), XG.Duration(s.elapsed),
            XG.Money(gph), zone))
    end
    XG.cdb.session = nil
    XG:UpdateHUD()
    if XG.RefreshUI then XG:RefreshUI() end
end

-- Moyenne des po/heure par zone sur tes sessions passées
function XG:ZoneStats()
    local z = {}
    for _, s in ipairs(XG.db.sessions) do
        local e = z[s.zone] or {zone = s.zone, n = 0, dur = 0, total = 0}
        e.n, e.dur, e.total = e.n + 1, e.dur + s.dur, e.total + s.value + s.money
        z[s.zone] = e
    end
    local out = {}
    for _, e in pairs(z) do e.gph = e.dur > 0 and e.total / e.dur * 3600 or 0; out[#out + 1] = e end
    table.sort(out, function(a, b) return a.gph > b.gph end)
    return out
end

------------------------------------------------------------------------
-- Événements
------------------------------------------------------------------------
local f = CreateFrame("Frame")
XG.Reg(f, "CHAT_MSG_LOOT", "PLAYER_MONEY", "PLAYER_ENTERING_WORLD")
for ev in pairs(BUSY_EVENTS) do XG.Reg(f, ev) end
f:SetScript("OnEvent", function(_, event, msg)
    if not XG.cdb then return end
    local tag = BUSY_EVENTS[event]
    if tag then
        busy[tag] = (event:find("SHOW") or event:find("OPENED")) and true or nil
        XG.lastMoney = GetMoney()
        return
    end
    local s = S()
    if event == "PLAYER_ENTERING_WORLD" then
        XG.lastMoney = GetMoney()
        -- après un /reload, la session reprend où elle en était
        if s and s.running and not s.resumedAt then s.resumedAt = GetTime() end
        XG:UpdateHUD()
        return
    end
    if not s or not s.running then return end
    if event == "CHAT_MSG_LOOT" then
        local link, n
        for _, p in ipairs(MULTI) do
            link, n = msg:match(p)
            if link then break end
        end
        if not link then
            for _, p in ipairs(SINGLE) do
                link = msg:match(p)
                if link then n = 1 break end
            end
        end
        local id = link and tonumber(link:match("item:(%d+)"))
        if id then
            s.items[id] = (s.items[id] or 0) + (tonumber(n) or 1)
            XG:UpdateHUD()
        end
    elseif event == "PLAYER_MONEY" then
        local now = GetMoney()
        local delta = now - (XG.lastMoney or now)
        XG.lastMoney = now
        if delta > 0 and not next(busy) then
            s.money = (s.money or 0) + delta
            XG:UpdateHUD()
        end
    end
end)

-- Avant un /reload : on garde le temps écoulé
local saver = CreateFrame("Frame")
XG.Reg(saver, "PLAYER_LOGOUT")
saver:SetScript("OnEvent", function()
    local s = S()
    if s and s.running then
        s.elapsed = XG:SessionElapsed()
        s.resumedAt = nil
    end
end)

-- Temps passé par zone (toutes les 5 s)
C_Timer.NewTicker(5, function()
    local s = XG.cdb and S()
    if s and s.running then
        if not s.resumedAt then s.resumedAt = GetTime() end
        local z = GetRealZoneText and GetRealZoneText() or "?"
        s.zones[z] = (s.zones[z] or 0) + 5
    end
    XG:UpdateHUD()
end)

------------------------------------------------------------------------
-- Petit bandeau flottant pendant le farm
------------------------------------------------------------------------
local hud
function XG:UpdateHUD()
    if not XG.cdb then return end
    local s = S()
    if not s or not XG.S.sessionHUD then
        if hud then hud:Hide() end
        return
    end
    if not hud then
        if not XG.CreateHUD then return end
        hud = XG:CreateHUD()
    end
    local total, gph = XG:SessionTotals()
    hud.time:SetText((s.running and "" or (XG.C.yellow .. "En pause|r  ")) .. XG.Duration(XG:SessionElapsed()))
    hud.total:SetText(XG.Money(total))
    hud.gph:SetText(XG.Money(gph) .. XG.C.grey .. " /h|r")
    hud.toggle:SetText(s.running and "Pause" or "Reprendre")
    hud:Show()
end
