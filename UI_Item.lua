-- XbiGold : fiche d'un objet (courbe des prix sur 21 jours, meilleures heures pour vendre)
local _, XG = ...

local UI, R, C = XG.UI, XG.RGB, XG.C
local floor, max, min = math.floor, math.max, math.min
local W, H = 600, 500
local fr

local GOLD = {1, 0.78, 0.1}
local BLUE = {0.31, 0.76, 0.97}

local function pctText(v)
    local s = XG.Num(math.abs(v) * 100) .. " %"
    if v >= 0 then return C.green .. "+" .. s .. "|r" end
    return C.red .. "-" .. s .. "|r"
end

-- Cherche un objet suivi par son nom (exact d'abord, sinon le premier qui contient le texte)
function XG:FindItemByName(text)
    text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    local partial
    for key in pairs(XG.M.items) do
        local id = XG.IDFromKey(key)
        local n = id and XG.ItemName(id)
        if n then
            local ln = n:lower()
            if ln == text then return id, key end
            if not partial and ln:find(text, 1, true) then partial = {id, key} end
        end
    end
    if partial then return partial[1], partial[2] end
    return nil
end

local function create()
    fr = CreateFrame("Frame", "XbiGoldItemFrame", UIParent)
    fr:SetSize(W, H)
    fr:SetPoint("CENTER", 120, 0)
    fr:SetFrameStrata("DIALOG")
    fr:SetToplevel(true)
    fr:SetClampedToScreen(true)
    fr:SetMovable(true)
    fr:EnableMouse(true)
    fr:RegisterForDrag("LeftButton")
    fr:SetScript("OnDragStart", fr.StartMoving)
    fr:SetScript("OnDragStop", fr.StopMovingOrSizing)
    UI.Fill(fr, R.bg, 0.98)
    UI.Border(fr, 1, 0.78, 0.1, 0.35)
    tinsert(UISpecialFrames, "XbiGoldItemFrame")
    fr:SetScale(XG.S.scale or 1)

    fr.icon = fr:CreateTexture(nil, "ARTWORK")
    fr.icon:SetSize(36, 36)
    fr.icon:SetPoint("TOPLEFT", 16, -14)
    fr.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    fr.name = UI.Text(fr, 15, R.text)
    fr.name:SetPoint("TOPLEFT", fr.icon, "TOPRIGHT", 10, -1)
    fr.name:SetWidth(250)
    fr.sub = UI.Text(fr, 11, R.muted)
    fr.sub:SetPoint("BOTTOMLEFT", fr.icon, "BOTTOMRIGHT", 10, 1)
    fr.sub:SetWidth(250)
    local close = UI.Button(fr, "X", 26, 26, "ghost", function() fr:Hide() end)
    close:SetPoint("TOPRIGHT", -12, -12)
    fr.search = UI.Search(fr, 150, "Autre objet (nom)...")
    fr.search:SetPoint("RIGHT", close, "LEFT", -8, 0)
    fr.ahBtn = UI.Button(fr, "Chercher à l'HV", 118, 26, "primary", function() if fr.id then XG:SearchAH(fr.id) end end)
    fr.ahBtn:SetPoint("RIGHT", fr.search, "LEFT", -8, 0)
    fr.search:SetScript("OnEnterPressed", function(self)
        local id, key = XG:FindItemByName(self:GetText())
        self:ClearFocus()
        if id then self:SetText(""); XG:ShowItem(id, key) else XG.Print("aucun objet suivi ne correspond.") end
    end)
    local hit = CreateFrame("Frame", nil, fr)
    hit:SetAllPoints(fr.icon)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(self) if fr.id then UI.ItemTooltip(self, fr.id, fr.key, nil, true) end end)
    hit:SetScript("OnLeave", GameTooltip_Hide)

    fr.cards = {}
    local titles = {"Valeur (7 j)", "Prix le plus bas", "En vente", "Ventes / jour"}
    for i = 1, 4 do
        local c = UI.Card(fr, 136, 62, titles[i])
        c:SetPoint("TOPLEFT", 16 + (i - 1) * 142, -64)
        fr.cards[i] = c
    end

    local t1 = UI.Text(fr, 12, GOLD)
    t1:SetPoint("TOPLEFT", 16, -138)
    t1:SetText("PRIX SUR 21 JOURS")
    local leg = UI.Text(fr, 10, R.muted, "RIGHT")
    leg:SetPoint("TOPRIGHT", -16, -139)
    leg:SetText("|TInterface\\Buttons\\WHITE8X8:8:8:0:0:8:8:0:8:0:8:255:199:25|t valeur marché    |TInterface\\Buttons\\WHITE8X8:8:8:0:0:8:8:0:8:0:8:79:194:247|t prix le plus bas    |TInterface\\Buttons\\WHITE8X8:8:8:0:0:8:8:0:8:0:8:110:110:110|t quantité en vente")
    fr.chart = UI.Chart(fr, W - 32, 160)
    fr.chart:SetPoint("TOPLEFT", 16, -156)

    local t2 = UI.Text(fr, 12, GOLD)
    t2:SetPoint("TOPLEFT", 16, -328)
    t2:SetText("SELON L'HEURE DE LA JOURNÉE")
    fr.hourInfo = UI.Text(fr, 10, R.muted, "RIGHT")
    fr.hourInfo:SetPoint("TOPRIGHT", -16, -329)
    fr.hours = UI.Chart(fr, W - 32, 96)
    fr.hours:SetPoint("TOPLEFT", 16, -346)

    fr.advice = UI.Text(fr, 12, R.text)
    fr.advice:SetPoint("TOPLEFT", 16, -452)
    fr.advice:SetWidth(W - 32)
    fr.advice:SetWordWrap(true)
    fr.advice:SetSpacing(3)
end

local function dayLabel(day)
    return date("%d/%m", day * 86400 + 43200)
end

function XG:ShowItem(id, key)
    if not id then return end
    if not fr then create() end
    key = tostring(key or id)
    fr.id, fr.key = id, key
    local it = XG:Item(key) or XG:Item(id)
    if not XG:Item(key) and XG:Item(id) then key = tostring(id) end
    local info = XG.ItemInfo(id)
    fr.icon:SetTexture(XG.ItemIcon(id))
    fr.name:SetText(info and (XG.QualityColor(info.quality) .. info.name .. "|r") or ("Objet " .. id))
    local subs = {}
    local q = XG.QUEST_DEMAND[id]
    if q then subs[#subs + 1] = C.orange .. "objet de quête (" .. q[1] .. ")|r" end
    if info and info.sell and info.sell > 0 then subs[#subs + 1] = "marchand " .. XG.Money(info.sell) end
    if it and it.t then subs[#subs + 1] = "vu " .. XG.Ago(it.t) end
    fr.sub:SetText(table.concat(subs, "  ·  "))

    -- tuiles
    local v = XG:Value(key)
    local tr = XG:Trend(key)
    fr.cards[1].value:SetText(v and XG.Money(v) or (C.grey .. "-|r"))
    fr.cards[1].sub:SetText(tr and ("tendance " .. pctText(tr)) or "pas encore de tendance")
    fr.cards[2].value:SetText(it and it.l and XG.Money(it.l) or (C.grey .. "-|r"))
    fr.cards[2].sub:SetText((it and it.l and v and v > 0) and (pctText(it.l / v - 1) .. " vs valeur") or "")
    fr.cards[3].value:SetText(it and (it.q == 0 and (C.orange .. "aucune|r") or XG.Num(it.q or 0)) or (C.grey .. "-|r"))
    fr.cards[3].sub:SetText(it and it.n and it.n > 0 and (it.n .. " annonce(s)") or "")
    local sales = XG:SalesPerDay(key)
    fr.cards[4].value:SetText(sales and ("~" .. XG.Num(sales, sales < 10 and 1 or 0)) or (C.grey .. "?|r"))
    fr.cards[4].sub:SetText(sales and "estimation" or "il faut 2 scans < 12 h")

    -- courbe 21 jours
    local days = {}
    if it and it.d then for day in pairs(it.d) do days[#days + 1] = day end end
    table.sort(days)
    local today = XG.Today()
    local first = days[1] or today
    first = math.min(first, today - 6) -- au moins une semaine affichée
    local span = math.max(1, today - first)
    local xs, mk, lowS, qty = {}, {}, {}, {}
    for i, day in ipairs(days) do
        xs[i] = (day - first) / span
        mk[i] = it.d[day]
        lowS[i] = it.dl and it.dl[day] or nil
        qty[i] = it.v and it.v[day] or nil
    end
    local xl = {}
    for k = 0, 3 do
        local day = floor(first + span * k / 3 + 0.5)
        xl[#xl + 1] = {x = (day - first) / span, text = day == today and "auj." or dayLabel(day)}
    end
    fr.chart:Draw({
        xs = xs,
        series = {{values = lowS, color = BLUE, thick = 1.5, dotSize = 3}, {values = mk, color = GOLD, thick = 2.5}},
        bars = {values = qty, color = {1, 1, 1, 0.12}, height = 0.3},
        yFmt = function(val) return XG.Money(val, true) end,
        xLabels = xl,
        emptyText = #days == 0 and "Pas encore d'historique : scanne l'HV (ou attends un scan de ta guilde)." or
            (#days == 1 and "Un seul jour de données pour l'instant : la courbe se remplit jour après jour." or nil),
        hover = function(i)
            local day = days[i]
            local lines = {(day == today and "Aujourd'hui" or date("%d/%m", day * 86400 + 43200))}
            lines[#lines + 1] = C.gold .. "Valeur marché : |r" .. XG.Money(mk[i])
            if lowS[i] then lines[#lines + 1] = C.blue .. "Plus bas : |r" .. XG.Money(lowS[i]) end
            if qty[i] then lines[#lines + 1] = C.grey .. "En vente (max du jour) : |r" .. XG.Num(qty[i]) end
            return lines
        end,
    })

    -- profil horaire
    local hs, known = XG:HourStats(key)
    local hx, hv, hcol = {}, {}, {}
    local best = {}
    if hs then
        for h = 0, 23 do
            local e = hs[h]
            hx[h + 1] = (h + 0.5) / 24
            if e then
                hv[h + 1] = max(0.02, 1 + e.price) -- hauteur = prix relatif
                best[#best + 1] = e
            end
        end
        table.sort(best, function(a, b) return a.price > b.price end)
    else
        for h = 0, 23 do hx[h + 1] = (h + 0.5) / 24 end
    end
    local top = {}
    for i = 1, min(3, #best) do top[best[i].h] = true end
    for h = 0, 23 do
        hcol[h + 1] = top[h] and {0.25, 0.89, 0.36, 0.9} or {0.31, 0.76, 0.97, 0.35}
    end
    -- les barres partent de la plus basse pour bien voir les écarts
    local minV = math.huge
    for h = 1, 24 do if hv[h] then minV = min(minV, hv[h]) end end
    for h = 1, 24 do if hv[h] then hv[h] = hv[h] - minV * 0.9 end end
    local hl = {}
    for _, h in ipairs({0, 6, 12, 18, 23}) do hl[#hl + 1] = {x = (h + 0.5) / 24, text = h .. "h"} end
    fr.hours:Draw({
        xs = hx, barsOnly = true,
        bars = {values = hv, colors = hcol, width = 0.75},
        xLabels = hl,
        emptyText = (known or 0) < 3 and "Pas assez d'heures différentes : il faut des scans à plusieurs moments de la journée (toi et ta guilde)." or nil,
        hover = function(i)
            local e = hs and hs[i - 1]
            if not e then return {(i - 1) .. "h", C.grey .. "pas de données|r"} end
            return {(i - 1) .. "h - " .. i .. "h", "Prix : " .. pctText(e.price) .. " vs la moyenne",
                    "Annonces : " .. pctText(e.qty), C.grey .. e.n .. " relevé(s)|r"}
        end,
    })
    fr.hourInfo:SetText((known or 0) > 0 and (known .. " / 24 heures connues") or "")

    -- conseil
    local adv = {}
    if hs and known >= 3 and best[1] and best[1].price >= 0.03 then
        local b = best[1]
        local worst = best[#best]
        adv[#adv + 1] = ("%sMeilleur moment pour vendre : vers %dh|r (prix %s, annonces %s)."):format(C.green, b.h, pctText(b.price), pctText(b.qty))
        if worst and worst.price < -0.03 then
            adv[#adv + 1] = ("Évite vers %dh (prix %s). "):format(worst.h, pctText(worst.price)) ..
                "Pour acheter, c'est l'inverse : vise ces heures-là."
        end
    elseif hs and known >= 3 then
        adv[#adv + 1] = C.grey .. "Le prix varie peu selon l'heure : vends quand tu veux.|r"
    end
    if tr and tr >= 0.15 then adv[#adv + 1] = C.green .. "Le prix monte depuis 2 jours : bon moment pour vendre ce que tu as.|r"
    elseif tr and tr <= -0.15 then adv[#adv + 1] = C.orange .. "Le prix baisse : vends vite, ou garde en attendant que ça remonte.|r" end
    if it and it.q == 0 and v then adv[#adv + 1] = C.orange .. "Personne n'en vend en ce moment : tu peux fixer ton prix.|r" end
    if #adv == 0 then adv[1] = C.grey .. "Les conseils apparaîtront avec plus de scans (quelques jours, à des heures différentes).|r" end
    fr.advice:SetText(table.concat(adv, "\n"))

    XG:UpdateItemFrameAH()
    fr:Show()
    fr:Raise()
end

function XG:UpdateItemFrameAH()
    if not fr then return end
    fr.ahBtn:SetEnabled(XG.ahOpen)
    fr.ahBtn.tip = XG.ahOpen and "Lance la recherche de cet objet dans l'hôtel des ventes." or "Ouvre l'hôtel des ventes pour pouvoir y chercher l'objet."
end

-- Alt+clic sur un objet (sacs, discussion...) : ouvre sa fiche
if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if not IsAltKeyDown() or not link or not XG.M then return end
        local key, id = XG.KeyFromLink(link)
        if id then XG:ShowItem(id, key) end
    end)
end
