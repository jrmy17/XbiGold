-- XbiGold : contenu des onglets
local _, XG = ...

local UI, R, C = XG.UI, XG.RGB, XG.C
local floor, max, min = math.floor, math.max, math.min

------------------------------------------------------------------------
-- Aides communes
------------------------------------------------------------------------
local function itemLabel(id, key)
    local info = XG.ItemInfo(id)
    if not info then return C.grey .. "Chargement..." .. "|r" end
    local suffix = key and tostring(key):find(":") and (C.grey .. " *|r") or ""
    return XG.QualityColor(info.quality) .. info.name .. "|r" .. suffix
end

local function iconCol(width, label)
    return {label = label or "Objet", width = width or "fill",
            icon = function(d) return XG.ItemIcon(d.id) end,
            text = function(d) return itemLabel(d.id, d.key) end,
            sort = function(d) return XG.ItemName(d.id) or "" end}
end

local function confText(c)
    if c == 3 then return C.green .. "haute|r" end
    if c == 2 then return C.yellow .. "moy.|r" end
    return C.orange .. "basse|r"
end

-- Vitesse de revente d'une affaire : ventes par jour et jours pour tout écouler
function XG.DealSellInfo(d)
    if d.type == "vendor" then d.sales, d.days = nil, 0 return end
    local s = XG:SalesPerDay(d.key)
    if not s and tostring(d.key) ~= tostring(d.id) then s = XG:SalesPerDay(d.id) end
    d.sales = (s and s > 0) and s or nil
    d.days = d.sales and d.qty / d.sales or nil
end

function XG.DaysText(days)
    if not days then return "?" end
    if days < 1 then return "moins d'un jour" end
    if days < 1.5 then return "1 jour" end
    return XG.Num(days) .. " jours"
end

function XG.SellTimeText(d)
    if d.type == "vendor" then return C.green .. "immédiat|r" end
    local days = d.days
    if not days then return C.grey .. "?|r" end
    local col = days <= 3 and C.green or (days <= 7 and C.yellow or C.red)
    if days < 1 then return col .. "< 1 j|r" end
    if days > 30 then return col .. "> 30 j|r" end
    return col .. XG.Num(days) .. " j|r"
end

local function heading(parent, text, sub)
    local t = UI.Text(parent, 15, R.text)
    t:SetText(text)
    local s
    if sub then
        s = UI.Text(parent, 11, R.muted)
        s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
        s:SetText(sub)
        s:SetWidth(680)
        s:SetWordWrap(true)
    end
    return t, s
end

local function zoneList(zones, maxN)
    local out = {}
    for i = 1, min(#zones, maxN or 3) do
        local n = XG.ZoneName(zones[i])
        if n ~= "" then out[#out + 1] = n end
    end
    if #zones > (maxN or 3) then out[#out + 1] = "..." end
    return table.concat(out, ", ")
end

-- Clic : à l'HV, cherche l'objet ; sinon, ouvre sa fiche. Clic droit : fiche. Maj+clic : lien.
local function onRowClick(_, d, button)
    XG.RowClick(d.id, d.key, button)
end

local function levelText(a, b)
    if not a then return "" end
    if a == b then return tostring(a) end
    return a .. "-" .. b
end

------------------------------------------------------------------------
-- Accueil
------------------------------------------------------------------------
local home = {}
XG:RegisterPage("home", "Accueil", "Interface\\Icons\\INV_Misc_Coin_01", function(f)
    local t = heading(f, "Bonjour " .. (UnitName("player") or "") .. " !")
    t:SetPoint("TOPLEFT")
    home.cards = {}
    local titles = {"Bonnes affaires", "Valeur de tes sacs", "Session de farm", "Marché suivi"}
    for i = 1, 4 do
        local c = UI.Card(f, 163, 66, titles[i])
        c:SetPoint("TOPLEFT", (i - 1) * 171, -30)
        home.cards[i] = c
    end

    -- Étapes
    local steps = CreateFrame("Frame", nil, f)
    steps:SetPoint("TOPLEFT", 0, -110)
    steps:SetSize(330, 200)
    UI.Fill(steps, R.panel2)
    local st = UI.Text(steps, 12, {1, 0.82, 0})
    st:SetPoint("TOPLEFT", 12, -10)
    st:SetText("COMMENT FAIRE DE L'OR")
    local body = UI.Text(steps, 12, R.text)
    body:SetPoint("TOPLEFT", 12, -32)
    body:SetWidth(306)
    body:SetWordWrap(true)
    body:SetSpacing(5)
    body:SetText(
        C.gold .. "1.|r Ouvre l'hôtel des ventes : XbiGold scanne tout (auto, toutes les 15 min).\n" ..
        C.gold .. "2.|r " .. C.white .. "Bonnes affaires|r : achète les prix cassés, revends au prix conseillé.\n" ..
        C.gold .. "3.|r " .. C.white .. "À farmer|r : ce qui rapporte le plus pour ton niveau, et où le trouver.\n" ..
        C.gold .. "4.|r " .. C.white .. "Métiers|r et " .. C.white .. "Marchands|r : ce que tu peux fabriquer ou racheter pour revendre.\n" ..
        C.gold .. "5.|r Lance une " .. C.white .. "Session|r pendant ton farm pour connaître tes vrais po/heure.")

    -- Astuce
    local tip = CreateFrame("Frame", nil, f)
    tip:SetPoint("TOPLEFT", steps, "BOTTOMLEFT", 0, -10)
    tip:SetSize(330, 80)
    UI.Fill(tip, {0.31, 0.76, 0.97, 0.08})
    local tt = UI.Text(tip, 11, R.blue)
    tt:SetPoint("TOPLEFT", 12, -10)
    tt:SetText("ASTUCE FOREVER")
    home.tip = UI.Text(tip, 11, R.text)
    home.tip:SetPoint("TOPLEFT", 12, -28)
    home.tip:SetWidth(306)
    home.tip:SetWordWrap(true)
    tip:EnableMouse(true)
    tip:SetScript("OnMouseUp", function() home.tipIndex = (home.tipIndex or 1) % #XG.TIPS + 1; home.tip:SetText(XG.TIPS[home.tipIndex]) end)

    -- Meilleures affaires et farm pour ton niveau
    local dl = UI.Text(f, 12, {1, 0.82, 0})
    dl:SetPoint("TOPLEFT", 346, -110)
    dl:SetText("MEILLEURES AFFAIRES")
    home.deals = UI.Table(f, {
        iconCol("fill"),
        {label = "Profit", width = 80, align = "RIGHT", text = function(d) return C.green .. XG.Money(d.profit) .. "|r" end},
    }, {onClick = onRowClick,
        onEnter = function(r, d) UI.ItemTooltip(r, d.id, d.key) end})
    home.deals:SetPoint("TOPLEFT", 346, -128)
    home.deals:SetSize(338, 5 * 26 + 26)

    local fl = UI.Text(f, 12, {1, 0.82, 0})
    fl:SetPoint("TOPLEFT", 346, -294)
    fl:SetText("À FARMER À TON NIVEAU")
    home.farm = UI.Table(f, {
        iconCol("fill"),
        {label = "Valeur", width = 80, align = "RIGHT", text = function(d) return XG.Money(d.value) end},
    }, {onClick = onRowClick,
        onEnter = function(r, d) UI.ItemTooltip(r, d.id, nil, {C.grey .. (d.where or "") .. "|r"}) end})
    home.farm:SetPoint("TOPLEFT", 346, -312)
    home.farm:SetSize(338, 5 * 26 + 26)
end, function(f)
    local M = XG.M
    local deals = M.deals or {}
    local sum = 0
    for _, d in ipairs(deals) do sum = sum + d.profit end
    home.cards[1].value:SetText(#deals > 0 and (C.green .. XG.Money(sum) .. "|r") or "0")
    home.cards[1].sub:SetText(#deals .. " affaire(s) au dernier scan")
    local bagAH, bagV = XG:BagTotals()
    home.cards[2].value:SetText(XG.Money(bagAH + bagV))
    home.cards[2].sub:SetText("en vendant au mieux")
    if XG.cdb.session then
        local total, gph = XG:SessionTotals()
        home.cards[3].value:SetText(XG.Money(gph) .. C.grey .. "/h|r")
        home.cards[3].sub:SetText(XG.Money(total) .. " en " .. XG.Duration(XG:SessionElapsed()))
    else
        home.cards[3].value:SetText(C.grey .. "aucune|r")
        home.cards[3].sub:SetText("onglet Session pour démarrer")
    end
    home.cards[4].value:SetText(XG.Num(XG:CountItems()))
    home.cards[4].sub:SetText((M.lastScan or 0) > 0 and ("scan " .. XG.Ago(M.lastScan)) or "ouvre l'HV pour scanner")
    if not home.tipIndex then home.tipIndex = math.random(#XG.TIPS) end
    home.tip:SetText(XG.TIPS[home.tipIndex])
    local top = {}
    for i = 1, min(5, #deals) do top[i] = deals[i] end
    home.deals:SetData(top, (M.lastScan or 0) > 0 and "Aucune affaire au dernier scan." or "Ouvre l'hôtel des ventes pour lancer le premier scan.")
    local farm = XG:FarmRows("all", true)
    table.sort(farm, function(a, b) return (a.pot or 0) > (b.pot or 0) end)
    local ft = {}
    for i = 1, min(5, #farm) do ft[i] = farm[i] end
    home.farm:SetData(ft, "Scanne l'HV pour connaître les prix.")
end)

------------------------------------------------------------------------
-- Bonnes affaires
------------------------------------------------------------------------
local deals = {filter = "all"}
XG:RegisterPage("deals", "Bonnes affaires", "Interface\\Icons\\Ability_Hunter_SniperShot", function(f)
    local t, s = heading(f, "Bonnes affaires", "Annonces trop basses repérées au dernier scan. Achète, puis revends au prix conseillé (commission de 5 % déjà déduite). Maj+clic : lien dans la discussion.")
    t:SetPoint("TOPLEFT")
    deals.seg = UI.Segmented(f, {
        {value = "all", label = "Toutes", w = 70},
        {value = "flip", label = "Revente HV", w = 96},
        {value = "vendor", label = "Revente marchand", w = 126},
    }, function(v) deals.filter = v; XG:RefreshUI() end)
    deals.seg:SetPoint("TOPLEFT", 0, -50)
    deals.seg:Select("all")
    deals.info = UI.Text(f, 11, R.muted, "RIGHT")
    deals.info:SetPoint("TOPRIGHT", 0, -56)
    deals.fast = UI.Toggle(f, "Seulement ce qui se revend vite", function() return XG.S.fastOnly end,
        function(v) XG.S.fastOnly = v; XG:RefreshUI() end,
        "Cache les affaires dont les ventes estimées sont inconnues ou trop lentes (plus de 3 jours pour tout revendre).")
    deals.fast:SetWidth(240)
    deals.fast:SetPoint("TOPLEFT", deals.seg, "BOTTOMLEFT", 0, -8)
    deals.table = UI.Table(f, {
        iconCol("fill"),
        {label = "Qté", width = 40, align = "RIGHT", text = function(d) return XG.Num(d.qty) end, sort = function(d) return d.qty end},
        {label = "Revente", width = 74, align = "RIGHT", text = function(d) return XG.Money(d.resale) end, sort = function(d) return d.resale end},
        {label = "Profit", width = 74, align = "RIGHT", text = function(d) return C.green .. XG.Money(d.profit) .. "|r" end, sort = function(d) return d.profit end},
        {label = "Marge", width = 46, align = "RIGHT", text = function(d) return XG.Pct(d.margin) end, sort = function(d) return d.margin end},
        {label = "Ventes/j", width = 56, align = "RIGHT", text = function(d)
            if d.type == "vendor" then return C.grey .. "-|r" end
            return d.sales and ("~" .. XG.Num(d.sales, d.sales < 10 and 1 or 0)) or (C.grey .. "?|r") end,
         sort = function(d) return d.type == "vendor" and 1e9 or d.sales or -1 end},
        {label = "Écoulé en", width = 64, align = "CENTER", text = function(d) return XG.SellTimeText(d) end,
         sort = function(d) return d.days and -d.days or -1e9 end},
        {label = "Fiab.", width = 40, align = "CENTER", text = function(d) return confText(d.conf) end, sort = function(d) return d.conf end},
        {label = "", width = 64, button = "Acheter", onClick = function(d) XG:BuyDeal(d) end,
         state = function() return true, "Acheter", XG.ahOpen end},
    }, {sortCol = 4, onClick = onRowClick, onEnter = function(r, d)
        local lines = {}
        if d.type == "vendor" then
            lines[#lines + 1] = C.green .. "Moins cher que le prix du marchand : achète et revends au PNJ, sans risque.|r"
        else
            lines[#lines + 1] = ("Achète jusqu'à %s l'unité (coût %s), revends à %s."):format(XG.Money(d.maxUnit), XG.Money(d.cost), XG.Money(d.resale))
            if d.ref then lines[#lines + 1] = C.grey .. "Valeur habituelle : " .. XG.Money(d.ref) .. "|r" end
            if d.sales then
                local col = (d.days or 99) <= 3 and C.green or ((d.days or 99) <= 7 and C.yellow or C.red)
                lines[#lines + 1] = col .. ("Il s'en vend ~%s par jour : tes %d partiront en ~%s.|r"):format(
                    XG.Num(d.sales, d.sales < 10 and 1 or 0), d.qty, XG.DaysText(d.days))
            else
                lines[#lines + 1] = C.orange .. "Ventes encore inconnues : il faut 2 scans à moins de 12 h d'écart (toi ou ta guilde). Prudence sur les grosses quantités.|r"
            end
            lines[#lines + 1] = C.grey .. "Fiabilité : " .. (d.conf == 3 and "élevée (historique + ventes)" or d.conf == 2 and "moyenne (peu d'historique)" or "faible (pas d'historique, prudence)") .. "|r"
        end
        lines[#lines + 1] = C.grey .. "Vu " .. XG.Ago(d.t) .. " · " .. XG.Num(d.total or 0) .. " en vente au total|r"
        UI.ItemTooltip(r, d.id, d.key, lines)
    end})
    deals.table:SetPoint("TOPLEFT", 0, -112)
    deals.table:SetPoint("BOTTOMRIGHT")
end, function(f)
    local list = {}
    for _, d in ipairs(XG.M.deals or {}) do
        XG.DealSellInfo(d)
        local fast = d.type == "vendor" or (d.days and d.days <= 3)
        if (deals.filter == "all" or d.type == deals.filter) and (not XG.S.fastOnly or fast) then list[#list + 1] = d end
    end
    local M = XG.M
    deals.info:SetText((M.lastScan or 0) > 0 and ("Scan " .. XG.Ago(M.lastScan) .. (XG.ahOpen and "" or "  ·  ouvre l'HV pour acheter")) or "")
    local msg = (M.lastScan or 0) > 0
        and "Aucune affaire au dernier scan.\nLes vraies erreurs de prix partent vite : rescanne dans 15 min."
        or "Pas encore de scan.\nOuvre l'hôtel des ventes : le premier scan se lance tout seul."
    deals.table:SetData(list, msg)
end)

------------------------------------------------------------------------
-- À farmer
------------------------------------------------------------------------
local farm = {cat = "all", myLevel = true, search = ""}

-- Construit la liste des objets à farmer (liste Forever + objets de quête)
function XG:FarmRows(cat, myLevel, search)
    local rows, seen = {}, {}
    local L = UnitLevel("player") or 60
    local myFac = XG.PlayerFaction()
    local function add(id, c, lv1, lv2, where, note, q)
        if seen[id] then return end
        local isOther = (c == "cook" or c == "fish" or c == "misc")
        if cat ~= "all" then
            if cat == "quest" then
                if not q then return end
            elseif cat == "other" then
                if not isOther then return end
            elseif c ~= cat then
                return
            end
        end
        if myLevel and lv1 and lv1 > L + 2 then return end
        if q and q[5] ~= 3 and q[5] ~= myFac and c == "quest" then return end -- demandé seulement par l'autre faction
        local v = XG:Value(id)
        local it = XG:Item(id)
        local sales = XG:SalesPerDay(id)
        local supply = it and it.q
        -- potentiel journalier : valeur x ventes (ou une part de l'offre si on ne connaît pas les ventes)
        local liquid = sales or (supply and min(300, supply * 0.15)) or 0
        if q then liquid = liquid + q[2] * 0.2 end
        local row = {id = id, cat = c, lv1 = lv1, lv2 = lv2, where = where, note = note, quest = q,
                     value = v, supply = supply, sales = sales, liquid = liquid,
                     pot = v and v * math.sqrt(min(liquid, 200)) or 0}
        if search and search ~= "" then
            local n = (XG.ItemName(id) or ""):lower()
            if not n:find(search:lower(), 1, true) then return end
        end
        seen[id] = true
        rows[#rows + 1] = row
    end
    for _, e in ipairs(XG.FARM) do
        add(e.id, e.cat, e.lv[1], e.lv[2], zoneList(e.z), e.note, XG.QUEST_DEMAND[e.id])
    end
    for id, q in pairs(XG.QUEST_DEMAND) do
        local where = {}
        for i = 7, #q do
            local src = q[i]
            if type(src) == "table" then
                local zn = XG.ZoneName(src[2])
                where[#where + 1] = src[1] .. (zn ~= "" and (" (" .. zn .. ")") or "") .. " " .. src[3] .. " %"
            end
        end
        local lv1 = max(1, (q[3] or 1) - 5)
        add(id, "quest", lv1, q[4], table.concat(where, ", "), q[6], q)
    end
    return rows
end

-- Ouvre l'onglet À farmer sur une catégorie (utilisé par l'onglet Métiers)
function XG:OpenFarm(cat)
    farm.cat = cat or "all"
    if farm.seg then farm.seg:Select(farm.cat) end
    XG:Open("farm")
end

XG:RegisterPage("farm", "À farmer", "Interface\\Icons\\INV_Misc_Herb_07", function(f)
    local t = heading(f, "À farmer", "Ce qui se vend le mieux, d'après tes scans. Trié par intérêt (valeur et demande). « Demande » vient des ventes estimées entre tes scans. Passe la souris pour voir où farmer.")
    t:SetPoint("TOPLEFT")
    farm.seg = UI.Segmented(f, XG.FARM_CATS, function(v) farm.cat = v; XG:RefreshUI() end)
    farm.seg:SetPoint("TOPLEFT", 0, -50)
    farm.seg:Select("all")
    farm.lvl = UI.Toggle(f, "Mon niveau", function() return farm.myLevel end, function(v) farm.myLevel = v; XG:RefreshUI() end,
        "Cache ce qui demande un niveau trop élevé pour toi.")
    farm.lvl:SetWidth(110)
    farm.lvl:SetPoint("TOPLEFT", farm.seg, "BOTTOMLEFT", 0, -8)
    farm.searchBox = UI.Search(f, 200, "Filtrer par nom...", function(txt) farm.search = txt; XG:RefreshUI() end)
    farm.searchBox:SetPoint("TOPRIGHT", 0, -82)
    farm.table = UI.Table(f, {
        iconCol("fill"),
        {label = "Type", width = 58, text = function(d) return (d.quest and d.cat ~= "quest") and (XG.CAT_LABEL[d.cat] .. C.orange .. "*|r") or XG.CAT_LABEL[d.cat] or "" end, sort = function(d) return d.cat end},
        {label = "Niv.", width = 42, align = "CENTER", text = function(d) return levelText(d.lv1, d.lv2) end, sort = function(d) return d.lv1 or 0 end},
        {label = "Valeur", width = 74, align = "RIGHT", text = function(d) return d.value and XG.Money(d.value) or (C.grey .. "?|r") end, sort = function(d) return d.value or 0 end},
        {label = "En vente", width = 60, align = "RIGHT", text = function(d) return d.supply and (d.supply == 0 and (C.orange .. "0|r") or XG.Num(d.supply)) or (C.grey .. "-|r") end, sort = function(d) return d.supply or -1 end},
        {label = "Ventes/j", width = 56, align = "RIGHT", text = function(d) return d.sales and ("~" .. XG.Num(d.sales)) or (C.grey .. "-|r") end, sort = function(d) return d.sales or -1 end},
        {label = "Demande", width = 70, align = "CENTER", text = function(d)
            if not d.value then return C.grey .. "?|r" end
            if d.liquid >= 40 then return C.green .. "forte|r" end
            if d.liquid >= 8 then return C.yellow .. "moyenne|r" end
            return C.orange .. "faible|r" end, sort = function(d) return d.pot end},
        {label = "Où", width = 150, size = 11, text = function(d) return C.soft .. (d.where or "") .. "|r" end},
    }, {sortCol = 7, onClick = onRowClick, onEnter = function(r, d)
        local lines = {}
        if d.where and d.where ~= "" then lines[#lines + 1] = C.gold .. "Où : |r" .. d.where end
        if d.note then lines[#lines + 1] = C.grey .. d.note .. "|r" end
        if d.quest then
            local q = d.quest
            lines[#lines + 1] = C.orange .. "Demandé par " .. q[1] .. " quête(s) (" .. q[2] .. " au total), niv. " .. levelText(q[3], q[4]) .. "|r"
        end
        UI.ItemTooltip(r, d.id, nil, lines)
    end})
    farm.table:SetPoint("TOPLEFT", 0, -114)
    farm.table:SetPoint("BOTTOMRIGHT")
end, function(f)
    local rows = XG:FarmRows(farm.cat, farm.myLevel, farm.search)
    farm.table:SetData(rows, "Rien à afficher avec ces filtres.")
end)

------------------------------------------------------------------------
-- Marchands
------------------------------------------------------------------------
local vend = {mode = "open"}

local function knownFlips()
    local rows = {}
    for id, rec in pairs(XG.db.vendors) do
        if rec.c then
            local profit, margin, v = XG:VendorFlip(id, rec.c)
            if profit and margin >= (XG.S.minMargin or 0.25) and profit >= 20 then
                local npc, z, lim, best = "?", "", nil, 0
                for name, info in pairs(rec.v or {}) do
                    if (info.t or 0) > best then npc, z, lim, best = name, info.z or "", info.lim, info.t or 0 end
                end
                local it = XG:Item(id)
                rows[#rows + 1] = {id = id, unit = rec.c, value = v, profit = profit, margin = margin, npc = npc, zone = z,
                                   lim = lim, supply = it and it.q, sales = XG:SalesPerDay(id)}
            end
        end
    end
    return rows
end

XG:RegisterPage("vendors", "Marchands", "Interface\\Icons\\INV_Misc_Bag_11", function(f)
    local t = heading(f, "Reventes de marchand", "Des PNJ vendent des objets moins cher que leur prix à l'HV (recettes, composants...). Ouvre un marchand : XbiGold affiche le bénéfice sur chaque objet.")
    t:SetPoint("TOPLEFT")
    vend.seg = UI.Segmented(f, {
        {value = "open", label = "Marchand ouvert", w = 120},
        {value = "known", label = "Reventes connues", w = 124},
        {value = "recipes", label = "Recettes en stock limité", w = 166},
    }, function(v) vend.mode = v; XG:RefreshUI() end)
    vend.seg:SetPoint("TOPLEFT", 0, -50)
    vend.seg:Select("open")
    vend.info = UI.Text(f, 11, R.muted, "RIGHT")
    vend.info:SetPoint("TOPRIGHT", 0, -56)

    local function tip(r, d)
        local lines = {}
        if d.npc then lines[#lines + 1] = C.gold .. "Vendu par : |r" .. d.npc .. (d.zone and d.zone ~= "" and (" (" .. d.zone .. ")") or "") end
        if d.lim then lines[#lines + 1] = C.orange .. "Stock limité : " .. d.lim .. " en stock|r" end
        if d.note then lines[#lines + 1] = C.grey .. d.note .. "|r" end
        if d.sales then lines[#lines + 1] = C.grey .. "Ventes estimées : ~" .. XG.Num(d.sales) .. " / jour|r" end
        UI.ItemTooltip(r, d.id, nil, lines)
    end

    vend.open = UI.Table(f, {
        iconCol("fill"),
        {label = "Prix PNJ", width = 76, align = "RIGHT", text = function(d) return XG.Money(d.unit) end, sort = function(d) return d.unit end},
        {label = "Valeur HV", width = 76, align = "RIGHT", text = function(d) return d.value and XG.Money(d.value) or (C.grey .. "?|r") end, sort = function(d) return d.value or 0 end},
        {label = "Bénéf./u", width = 76, align = "RIGHT", text = function(d) return d.profit and (C.green .. XG.Money(d.profit) .. "|r") or (C.grey .. "-|r") end, sort = function(d) return d.profit or -1 end},
        {label = "Marge", width = 50, align = "RIGHT", text = function(d) return d.margin and XG.Pct(d.margin) or "" end, sort = function(d) return d.margin or -1 end},
        {label = "Stock", width = 46, align = "RIGHT", text = function(d) return d.avail and d.avail > 0 and (C.orange .. d.avail .. "|r") or (C.grey .. "-|r") end, sort = function(d) return d.avail or -1 end},
        {label = "", width = 66, button = "Acheter", buttonStyle = "success", onClick = function(d) XG:BuyFromMerchant(d) end,
         state = function(d) return d.profit ~= nil, "Acheter", true end},
    }, {sortCol = 4, onClick = onRowClick, onEnter = tip})
    vend.open:SetPoint("TOPLEFT", 0, -84)
    vend.open:SetPoint("BOTTOMRIGHT")

    vend.known = UI.Table(f, {
        iconCol("fill"),
        {label = "Prix PNJ", width = 74, align = "RIGHT", text = function(d) return XG.Money(d.unit) end, sort = function(d) return d.unit end},
        {label = "Valeur HV", width = 74, align = "RIGHT", text = function(d) return XG.Money(d.value) end, sort = function(d) return d.value end},
        {label = "Bénéf./u", width = 74, align = "RIGHT", text = function(d) return C.green .. XG.Money(d.profit) .. "|r" end, sort = function(d) return d.profit end},
        {label = "Marge", width = 50, align = "RIGHT", text = function(d) return XG.Pct(d.margin) end, sort = function(d) return d.margin end},
        {label = "Marchand", width = 170, size = 11, text = function(d) return (d.lim and (C.orange .. "[stock] |r") or "") .. C.soft .. d.npc .. "|r" .. C.grey .. (d.zone ~= "" and (" · " .. d.zone) or "") .. "|r" end, sort = function(d) return d.npc end},
    }, {sortCol = 4, onClick = onRowClick, onEnter = tip})
    vend.known:SetPoint("TOPLEFT", 0, -84)
    vend.known:SetPoint("BOTTOMRIGHT")

    vend.recipes = UI.Table(f, {
        iconCol("fill"),
        {label = "Valeur HV", width = 80, align = "RIGHT", text = function(d) return d.value and XG.Money(d.value) or (C.grey .. "?|r") end, sort = function(d) return d.value or 0 end},
        {label = "En vente", width = 60, align = "RIGHT", text = function(d) return d.supply and XG.Num(d.supply) or (C.grey .. "-|r") end, sort = function(d) return d.supply or -1 end},
        {label = "Marchand", width = 130, size = 11, text = function(d) return C.soft .. d.npc .. "|r" end, sort = function(d) return d.npc end},
        {label = "Zone", width = 120, size = 11, text = function(d) return C.grey .. d.zone .. "|r" end, sort = function(d) return d.zone end},
    }, {sortCol = 2, onClick = onRowClick, onEnter = tip})
    vend.recipes:SetPoint("TOPLEFT", 0, -84)
    vend.recipes:SetPoint("BOTTOMRIGHT")
end, function(f)
    vend.open:SetShown(vend.mode == "open")
    vend.known:SetShown(vend.mode == "known")
    vend.recipes:SetShown(vend.mode == "recipes")
    if vend.mode == "open" then
        local m = XG.merchant
        vend.info:SetText(m and (m.npc .. " · " .. m.zone) or "")
        vend.open:SetData(m and m.items or {}, "Ouvre un marchand pour voir ce qui se revend.\nLe bénéfice s'affiche aussi en vert sur la fenêtre du marchand.")
    elseif vend.mode == "known" then
        local n = 0
        for _ in pairs(XG.db.vendors) do n = n + 1 end
        vend.info:SetText(XG.Num(n) .. " objets de marchands mémorisés")
        vend.known:SetData(knownFlips(), "Aucune revente connue pour l'instant.\nVisite des marchands (recettes, artisanat) puis scanne l'HV.")
    else
        local myFac = XG.PlayerFaction()
        local rows = {}
        for _, r in ipairs(XG.LIMITED_RECIPES) do
            if r.f == 0 or r.f == myFac then
                local it = XG:Item(r.id)
                rows[#rows + 1] = {id = r.id, npc = r.npc, zone = XG.ZoneName(r.z), note = r.note, value = XG:Value(r.id), supply = it and it.q}
            end
        end
        vend.info:SetText("Achète-les dès que le PNJ en a, revends-les à l'HV")
        vend.recipes:SetData(rows)
    end
end)

------------------------------------------------------------------------
-- Tendances
------------------------------------------------------------------------
local trends = {mode = "up"}
XG:RegisterPage("trends", "Tendances", "Interface\\Icons\\INV_Misc_Spyglass_02", function(f)
    local t = heading(f, "Tendances du marché", "Compare le prix des 2 derniers jours à la semaine passée. Achète ce qui baisse trop, vends ce qui monte, et remplis les rayons vides.")
    t:SetPoint("TOPLEFT")
    trends.seg = UI.Segmented(f, {
        {value = "up", label = "En hausse", w = 90},
        {value = "down", label = "En baisse", w = 90},
        {value = "empty", label = "Plus personne n'en vend", w = 170},
    }, function(v) trends.mode = v; XG:RefreshUI() end)
    trends.seg:SetPoint("TOPLEFT", 0, -50)
    trends.seg:Select("up")
    trends.table = UI.Table(f, {
        iconCol("fill"),
        {label = "Prix min", width = 80, align = "RIGHT", text = function(d) return d.low and XG.Money(d.low) or (C.grey .. "-|r") end, sort = function(d) return d.low or 0 end},
        {label = "Valeur 7 j", width = 80, align = "RIGHT", text = function(d) return XG.Money(d.value) end, sort = function(d) return d.value end},
        {label = "Variation", width = 70, align = "RIGHT", text = function(d)
            if not d.trend then return "" end
            return (d.trend >= 0 and C.green .. "+" or C.red) .. XG.Num(d.trend * 100) .. " %|r" end, sort = function(d) return d.trend or 0 end},
        {label = "En vente", width = 64, align = "RIGHT", text = function(d) return XG.Num(d.supply or 0) end, sort = function(d) return d.supply or 0 end},
        {label = "Ventes/j", width = 60, align = "RIGHT", text = function(d) return d.sales and ("~" .. XG.Num(d.sales)) or (C.grey .. "-|r") end, sort = function(d) return d.sales or -1 end},
    }, {sortCol = 4, onClick = onRowClick, onEnter = function(r, d) UI.ItemTooltip(r, d.id, d.key) end})
    trends.table:SetPoint("TOPLEFT", 0, -84)
    trends.table:SetPoint("BOTTOMRIGHT")
end, function(f)
    local rows = {}
    local now = time()
    for key, it in pairs(XG.M.items) do
        local id = XG.IDFromKey(key)
        local v, nd = XG:MarketValue(key)
        if id and v and v >= 100 then
            if trends.mode == "empty" then
                if (it.q or 0) == 0 and (it.t or 0) > now - 3 * 86400 and nd >= 2 then
                    rows[#rows + 1] = {id = id, key = key, value = v, supply = 0, low = nil, sales = it.sr}
                end
            else
                local tr = XG:Trend(key)
                if tr and ((trends.mode == "up" and tr >= 0.15) or (trends.mode == "down" and tr <= -0.15)) and (it.q or 0) > 0 then
                    rows[#rows + 1] = {id = id, key = key, value = v, supply = it.q, low = it.l, trend = tr, sales = it.sr}
                end
            end
        end
    end
    trends.table.sortCol = trends.mode == "empty" and 3 or 4
    trends.table.sortDesc = trends.mode ~= "down"
    trends.table:SetData(rows, "Il faut au moins 3 jours de scans pour voir les tendances.\nScanne l'HV chaque jour où tu joues.")
end)

------------------------------------------------------------------------
-- Mes sacs
------------------------------------------------------------------------
local bags = {}
local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetSlotInfo = C_Container and C_Container.GetContainerItemInfo

local function scanBags()
    local agg = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (GetNumSlots(bag) or 0) do
            local info = GetSlotInfo and GetSlotInfo(bag, slot)
            if info and info.itemID and info.hyperlink then
                local key = XG.KeyFromLink(info.hyperlink) or tostring(info.itemID)
                local a = agg[key]
                if not a then
                    a = {id = info.itemID, key = key, count = 0, bound = info.isBound, quality = info.quality, slots = {}}
                    agg[key] = a
                end
                a.count = a.count + (info.stackCount or 1)
                a.slots[#a.slots + 1] = {bag, slot}
            end
        end
    end
    local rows = {}
    for _, a in pairs(agg) do
        local where, unitAH, unitV, reason = XG:SellAdvice(a.key, a.id, a.count, a.bound)
        a.where, a.unitAH, a.unitV, a.reason = where, unitAH, unitV or 0, reason
        a.ahTotal = unitAH and unitAH * (1 - XG.AH_CUT) * a.count or 0
        a.vTotal = (unitV or 0) * a.count
        a.best = where == "hv" and a.ahTotal or a.vTotal
        if a.best > 0 or (XG.QUEST_DEMAND[a.id] and not a.bound) then rows[#rows + 1] = a end
    end
    return rows
end

function XG:BagTotals()
    local ah, v = 0, 0
    local ok, rows = pcall(scanBags)
    if not ok then return 0, 0 end
    for _, a in ipairs(rows) do
        if a.where == "hv" then ah = ah + a.ahTotal else v = v + a.vTotal end
    end
    return ah, v, rows
end

XG:RegisterPage("bags", "Mes sacs", "Interface\\Icons\\INV_Misc_Bag_10", function(f)
    local t = heading(f, "Que vendre, et où ?", "Pour chaque objet de tes sacs : HV ou marchand, et le prix à demander. Valeurs nettes de la commission de l'HV.")
    t:SetPoint("TOPLEFT")
    bags.sum = UI.Text(f, 13, R.text)
    bags.sum:SetPoint("TOPLEFT", 0, -54)
    bags.sellGrey = UI.Button(f, "Vendre les objets gris", 170, 26, "ghost", function()
        if not MerchantFrame or not MerchantFrame:IsShown() then XG.Print("ouvre un marchand d'abord.") return end
        local n, total = 0, 0
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            for slot = 1, (GetNumSlots(bag) or 0) do
                local info = GetSlotInfo and GetSlotInfo(bag, slot)
                if info and info.quality == 0 and not info.hasNoValue then
                    local ii = XG.ItemInfo(info.itemID)
                    total = total + (ii and ii.sell or 0) * (info.stackCount or 1)
                    C_Container.UseContainerItem(bag, slot)
                    n = n + 1
                end
            end
        end
        XG.Print(("%d objet(s) gris vendus pour %s."):format(n, XG.Money(total)))
    end)
    bags.sellGrey:SetPoint("TOPRIGHT", 0, -48)
    bags.table = UI.Table(f, {
        iconCol("fill"),
        {label = "Qté", width = 40, align = "RIGHT", text = function(d) return XG.Num(d.count) end, sort = function(d) return d.count end},
        {label = "Où vendre", width = 82, text = function(d)
            if d.where == "hv" then return C.green .. "HV|r" end
            if d.where == "marchand" then return C.yellow .. "Marchand|r" end
            return C.grey .. "Garder|r" end, sort = function(d) return d.where end},
        {label = "Prix / u", width = 78, align = "RIGHT", text = function(d)
            if d.where == "hv" then return XG.Money(XG:SuggestedPrice(d.key) or d.unitAH) end
            return XG.Money(d.unitV) end, sort = function(d) return d.unitAH or d.unitV or 0 end},
        {label = "HV (net)", width = 80, align = "RIGHT", text = function(d) return d.unitAH and XG.Money(d.ahTotal) or (C.grey .. "-|r") end, sort = function(d) return d.ahTotal end},
        {label = "Marchand", width = 76, align = "RIGHT", text = function(d) return XG.Money(d.vTotal) end, sort = function(d) return d.vTotal end},
        {label = "Pourquoi", width = 150, size = 11, text = function(d) return C.grey .. (d.reason or "") .. "|r" end},
    }, {sortCol = 5, onClick = onRowClick, onEnter = function(r, d)
        local lines = {}
        local p, why = XG:SuggestedPrice(d.key)
        if d.where == "hv" and p then lines[#lines + 1] = C.gold .. "Prix conseillé : " .. XG.Money(p) .. " l'unité|r" end
        if why then lines[#lines + 1] = C.orange .. why .. "|r" end
        UI.ItemTooltip(r, d.id, d.key, lines)
    end})
    bags.table:SetPoint("TOPLEFT", 0, -84)
    bags.table:SetPoint("BOTTOMRIGHT")
end, function(f)
    local ah, v, rows = XG:BagTotals()
    bags.sum:SetText(("À l'HV : %s   ·   Au marchand : %s   ·   %sTotal : %s|r"):format(XG.Money(ah), XG.Money(v), C.gold, XG.Money(ah + v)))
    bags.sellGrey:SetEnabled(MerchantFrame and MerchantFrame:IsShown() or false)
    bags.table:SetData(rows or {}, "Rien à vendre dans tes sacs.")
end)

------------------------------------------------------------------------
-- Session de farm
------------------------------------------------------------------------
local ses = {mode = "loot"}
XG:RegisterPage("session", "Session farm", "Interface\\Icons\\Spell_Holy_BorrowedTime", function(f)
    local t = heading(f, "Session de farm", "Compte tout ce que tu ramasses (butin + or) et le convertit en po/heure, au prix de l'HV ou du marchand.")
    t:SetPoint("TOPLEFT")
    ses.cards = {}
    local titles = {"Durée", "Gagné", "Par heure", "Zone"}
    for i = 1, 4 do
        local c = UI.Card(f, 163, 66, titles[i])
        c:SetPoint("TOPLEFT", (i - 1) * 171, -48)
        ses.cards[i] = c
    end
    ses.start = UI.Button(f, "Démarrer", 120, 28, "primary", function()
        if XG:SessionRunning() then XG:PauseSession() else XG:StartSession() end
        XG:RefreshUI()
    end)
    ses.start:SetPoint("TOPLEFT", 0, -124)
    ses.stop = UI.Button(f, "Terminer", 100, 28, "ghost", function() XG:StopSession() end)
    ses.stop:SetPoint("LEFT", ses.start, "RIGHT", 8, 0)
    ses.seg = UI.Segmented(f, {
        {value = "loot", label = "Butin", w = 70},
        {value = "history", label = "Historique", w = 90},
        {value = "zones", label = "Meilleures zones", w = 124},
    }, function(v) ses.mode = v; XG:RefreshUI() end)
    ses.seg:SetPoint("TOPRIGHT", 0, -126)
    ses.seg:Select("loot")

    ses.loot = UI.Table(f, {
        iconCol("fill"),
        {label = "Qté", width = 50, align = "RIGHT", text = function(d) return XG.Num(d.count) end, sort = function(d) return d.count end},
        {label = "Prix / u", width = 80, align = "RIGHT", text = function(d) return XG.Money(d.unit) end, sort = function(d) return d.unit end},
        {label = "Total", width = 86, align = "RIGHT", text = function(d) return C.gold .. XG.Money(d.total) .. "|r" end, sort = function(d) return d.total end},
        {label = "Vendre", width = 70, text = function(d) return d.src == "hv" and (C.green .. "HV|r") or (C.yellow .. "Marchand|r") end},
    }, {sortCol = 4, onClick = onRowClick, onEnter = function(r, d) UI.ItemTooltip(r, d.id) end})
    ses.hist = UI.Table(f, {
        {label = "Date", width = 90, text = function(d) return date("%d/%m %H:%M", d.t) end, sort = function(d) return d.t end},
        {label = "Zone", width = "fill", text = function(d) return d.zone end, sort = function(d) return d.zone end},
        {label = "Perso", width = 90, text = function(d) return C.grey .. (d.char or "") .. " (" .. (d.level or "?") .. ")|r" end},
        {label = "Durée", width = 64, align = "RIGHT", text = function(d) return XG.Duration(d.dur) end, sort = function(d) return d.dur end},
        {label = "Gagné", width = 86, align = "RIGHT", text = function(d) return XG.Money(d.value + d.money) end, sort = function(d) return d.value + d.money end},
        {label = "Par heure", width = 86, align = "RIGHT", text = function(d) return C.gold .. XG.Money(d.gph) .. "|r" end, sort = function(d) return d.gph end},
    }, {sortCol = 1})
    ses.zones = UI.Table(f, {
        {label = "Zone", width = "fill", text = function(d) return d.zone end, sort = function(d) return d.zone end},
        {label = "Sessions", width = 70, align = "RIGHT", text = function(d) return d.n end, sort = function(d) return d.n end},
        {label = "Temps total", width = 90, align = "RIGHT", text = function(d) return XG.Duration(d.dur) end, sort = function(d) return d.dur end},
        {label = "Moyenne / h", width = 100, align = "RIGHT", text = function(d) return C.gold .. XG.Money(d.gph) .. "|r" end, sort = function(d) return d.gph end},
    }, {sortCol = 4})
    for _, tb in ipairs({ses.loot, ses.hist, ses.zones}) do
        tb:SetPoint("TOPLEFT", 0, -164)
        tb:SetPoint("BOTTOMRIGHT")
    end
end, function(f)
    local s = XG.cdb.session
    local total, gph, itemsValue = XG:SessionTotals()
    ses.cards[1].value:SetText(s and XG.Duration(XG:SessionElapsed()) or C.grey .. "-|r")
    ses.cards[1].sub:SetText(s and (s.running and C.green .. "en cours|r" or C.yellow .. "en pause|r") or "pas de session")
    ses.cards[2].value:SetText(XG.Money(total))
    ses.cards[2].sub:SetText(s and (XG.Money(s.money or 0) .. " d'or + " .. XG.Money(itemsValue) .. " d'objets") or "")
    ses.cards[3].value:SetText(C.gold .. XG.Money(gph) .. "|r")
    ses.cards[3].sub:SetText("calculé après 1 min")
    local zone, best = "-", 0
    if s then for z, sec in pairs(s.zones) do if sec > best then zone, best = z, sec end end end
    ses.cards[4].value:SetText(zone)
    ses.start:SetText(s and s.running and "Pause" or (s and "Reprendre" or "Démarrer"))
    ses.stop:SetEnabled(s ~= nil)

    ses.loot:SetShown(ses.mode == "loot")
    ses.hist:SetShown(ses.mode == "history")
    ses.zones:SetShown(ses.mode == "zones")
    if ses.mode == "loot" then
        local rows = {}
        if s then
            for id, n in pairs(s.items) do
                local unit, src = XG:LootValue(id)
                rows[#rows + 1] = {id = id, count = n, unit = unit or 0, total = (unit or 0) * n, src = src}
            end
        end
        ses.loot:SetData(rows, s and "Rien ramassé pour l'instant." or "Clique sur Démarrer avant d'aller farmer.\nLe petit bandeau peut se déplacer (clic droit : ouvrir cet onglet).")
    elseif ses.mode == "history" then
        ses.hist:SetData(XG.db.sessions, "Aucune session terminée.")
    else
        ses.zones:SetData(XG:ZoneStats(), "Termine quelques sessions pour comparer les zones.")
    end
end)

------------------------------------------------------------------------
-- Partage (guilde et groupe)
------------------------------------------------------------------------
local share = {}
XG:RegisterPage("share", "Partage", "Interface\\Icons\\Ability_Warrior_RallyingCry", function(f)
    local t = heading(f, "Partage des prix", "Les membres de ta guilde et de ton groupe qui ont XbiGold s'échangent leurs scans en arrière-plan : chacun profite des prix les plus récents. Seuls les joueurs du même marché (type de royaume + faction) sont pris en compte.")
    t:SetPoint("TOPLEFT")
    local S = XG.S
    local tg1 = UI.Toggle(f, "Partager avec ma guilde", function() return S.share end, function(v) S.share = v; XG:RefreshUI() end,
        "Envoie tes scans et reçoit ceux des autres. Les valeurs absurdes par rapport à ton historique sont ignorées.")
    tg1:SetPoint("TOPLEFT", 0, -54)
    local tg2 = UI.Toggle(f, "Aussi avec mon groupe / raid", function() return S.shareGroup end, function(v) S.shareGroup = v end,
        "Utile avec des amis d'une autre guilde. Rien n'est envoyé deux fois aux membres de ta guilde.")
    tg2:SetPoint("TOPLEFT", 0, -80)
    share.sync = UI.Button(f, "Demander les derniers prix", 190, 26, "primary", function() XG:SyncRequest(); XG.Print("demande envoyée à la guilde et au groupe.") end)
    share.sync:SetPoint("TOPRIGHT", 0, -54)
    share.status = UI.Text(f, 12, R.text)
    share.status:SetPoint("TOPLEFT", 0, -114)
    share.status:SetWidth(680)
    share.status:SetWordWrap(true)
    share.status:SetSpacing(4)
    share.table = UI.Table(f, {
        {label = "Joueur", width = "fill", text = function(d) return (d.same and C.white or C.grey) .. d.name .. "|r" end, sort = function(d) return d.name end},
        {label = "Canal", width = 70, text = function(d) return C.grey .. (d.channel == "GUILD" and "Guilde" or "Groupe") .. "|r" end, sort = function(d) return d.channel or "" end},
        {label = "Ses prix", width = 110, align = "RIGHT", text = function(d) return d.fresh and d.fresh > 0 and XG.Ago(d.fresh) or (C.grey .. "aucun scan|r") end, sort = function(d) return d.fresh or 0 end},
        {label = "Objets", width = 70, align = "RIGHT", text = function(d) return XG.Num(d.count or 0) end, sort = function(d) return d.count or 0 end},
        {label = "Reçus de lui", width = 90, align = "RIGHT", text = function(d)
            return XG.Num(d.received or 0) .. ((d.rejected or 0) > 0 and (C.orange .. " (" .. d.rejected .. " ignorés)|r") or "") end, sort = function(d) return d.received or 0 end},
        {label = "Vu", width = 90, align = "RIGHT", text = function(d) return C.grey .. XG.Ago(d.seen) .. "|r" end, sort = function(d) return d.seen or 0 end},
    }, {sortCol = 3})
    share.table:SetPoint("TOPLEFT", 0, -170)
    share.table:SetPoint("BOTTOMRIGHT")
end, function(f)
    local M = XG.M
    local lines = {}
    if not XG.S.share then
        lines[#lines + 1] = C.grey .. "Partage désactivé.|r"
    else
        if M.shared and M.shared.t then
            lines[#lines + 1] = ("Derniers prix reçus : %s (scan de %s%s|r), %s objets reçus au total."):format(
                XG.Ago(M.shared.t), C.white, M.shared.from or "?", XG.Num(M.shared.count or 0))
        else
            lines[#lines + 1] = C.grey .. "Rien reçu pour l'instant : il faut qu'un autre joueur avec XbiGold soit connecté.|r"
        end
        local q = XG:SyncQueueSize()
        if q > 0 then
            lines[#lines + 1] = C.yellow .. ("Envoi en cours : %d message(s), environ %s.|r"):format(q, XG.Duration(q * 1.1))
        end
    end
    share.status:SetText(table.concat(lines, "\n"))
    local rows = {}
    for name, p in pairs(XG.peers) do
        rows[#rows + 1] = {name = name, channel = p.channel, fresh = p.fresh, count = p.count, received = p.received,
                           rejected = p.rejected, seen = p.seen, same = p.sameMarket ~= false}
    end
    share.table:SetData(rows, "Aucun autre joueur avec XbiGold vu pour l'instant.\nPartage le zip à ta guilde !")
end)

------------------------------------------------------------------------
-- Options
------------------------------------------------------------------------
XG:RegisterPage("options", "Options", "Interface\\Icons\\INV_Misc_Gear_01", function(f)
    local t = heading(f, "Options")
    t:SetPoint("TOPLEFT")
    local S = XG.S
    local y = -34
    local function toggle(label, key, tip, after)
        local tg = UI.Toggle(f, label, function() return S[key] end, function(v) S[key] = v; if after then after() end end, tip)
        tg:SetPoint("TOPLEFT", 0, y)
        y = y - 30
    end
    toggle("Prix dans les infobulles", "tooltip", "Valeur HV, prix marchand, ventes estimées et quêtes qui demandent l'objet.")
    toggle("Infobulles seulement avec Maj", "tooltipShift", "N'affiche les prix que si tu maintiens Maj.")
    toggle("Scan automatique à l'ouverture de l'HV", "autoScan", "Lance un scan complet quand tu ouvres l'HV (si 15 min se sont écoulées).")
    toggle("Ouvrir XbiGold avec l'HV", "openWithAH", "Affiche la fenêtre à côté de l'hôtel des ventes.")
    toggle("Alerte sonore pour les grosses affaires", "dealAlert")
    toggle("Bénéfice sur la fenêtre des marchands", "merchantOverlay")
    toggle("Bandeau de session de farm", "sessionHUD", nil, function() XG:UpdateHUD() end)
    toggle("Icône sur la minicarte", "minimap", nil, function() if XG.UpdateMinimapButton then XG:UpdateMinimapButton() end end)
    y = y - 10
    local st = UI.Stepper(f, "Profit minimum d'une affaire", {500, 1000, 2000, 5000, 10000, 20000, 50000, 100000},
        function(v) return XG.Money(v) end, function() return S.minProfit end, function(v) S.minProfit = v end)
    st:SetPoint("TOPLEFT", 0, y)
    y = y - 32
    local sm = UI.Stepper(f, "Marge minimum", {0.1, 0.15, 0.2, 0.25, 0.35, 0.5, 0.75, 1},
        function(v) return XG.Pct(v) end, function() return S.minMargin end, function(v) S.minMargin = v end)
    sm:SetPoint("TOPLEFT", 0, y)
    y = y - 32
    local sc = UI.Stepper(f, "Taille de la fenêtre", {0.8, 0.9, 1, 1.1, 1.2},
        function(v) return XG.Pct(v) end, function() return S.scale end, function(v) S.scale = v; if XbiGoldFrame then XbiGoldFrame:SetScale(v) end end)
    sc:SetPoint("TOPLEFT", 0, y)
    y = y - 40
    local note = UI.Text(f, 11, R.muted)
    note:SetPoint("TOPLEFT", 0, y)
    note:SetWidth(640)
    note:SetWordWrap(true)
    note:SetText("Les seuils s'appliquent au prochain scan. Les prix sont gardés 21 jours, séparément pour chaque marché (type de royaume + faction). " ..
        "XbiGold lit aussi les prix d'Auctionator et de TSM pour les objets qu'il n'a pas encore vus.\n\n" ..
        "Commandes : /xg (fenêtre), /xg scan, /xg session, /xg reset (efface les prix de ce marché).")
end, nil)
