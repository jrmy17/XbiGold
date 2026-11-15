-- XbiGold : onglet Métiers
local _, XG = ...

local UI, R, C = XG.UI, XG.RGB, XG.C
local floor, max, min = math.floor, math.max, math.min

local P = {mode = "profit", chips = {}}
XG.profUI = P
local DIFF_TEXT = {[0] = "orange", [1] = "jaune", [2] = "vert", [3] = "gris"}

local function recipeLabel(d)
    local name = d.r.name or "?"
    if d.r.out then
        local info = XG.ItemInfo(d.r.out)
        if info then name = XG.QualityColor(info.quality) .. info.name .. "|r" end
        if XG.QUEST_DEMAND[d.r.out] then name = name .. C.orange .. " (quête)|r" end
    end
    return name
end

local function recipeTooltip(row, d)
    local r, e = d.r, d.e
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if r.out then GameTooltip:SetHyperlink("item:" .. r.out) else GameTooltip:AddLine(r.name or "?", 1, 1, 1) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(C.gold .. "Composants|r" .. (e.qty > 1 and (C.grey .. "  (donne " .. XG.Num(e.qty, 1) .. " objets)|r") or ""))
    for _, rg in ipairs(r.reag or {}) do
        local c, src = XG:ReagentCost(rg[1])
        local nm = XG.ItemName(rg[1]) or ("Objet " .. rg[1])
        local have = (C_Item and C_Item.GetItemCount or GetItemCount)(rg[1]) or 0
        local srcTxt = src == "pnj" and " (PNJ)" or (src == "estimé" and " (PNJ, estimé)" or "")
        GameTooltip:AddDoubleLine(("%d × %s %s(%d en sac)|r"):format(rg[2], nm, C.grey, have),
            c and (XG.Money(c * rg[2]) .. C.grey .. srcTxt .. "|r") or (C.orange .. "prix inconnu|r"), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Coût", XG.Money(e.cost) .. (e.missing and (C.orange .. " + ?|r") or ""), 0.8, 0.83, 0.86, 1, 1, 1)
    if e.sellNet then
        GameTooltip:AddDoubleLine(e.value and "Vente HV (net)" or "Vente marchand", XG.Money(e.sellNet), 0.8, 0.83, 0.86, 1, 1, 1)
        local col = (e.profit or 0) >= 0 and C.green or C.red
        GameTooltip:AddDoubleLine("Profit", col .. XG.Money(e.profit) .. "|r", 0.8, 0.83, 0.86, 1, 1, 1)
    end
    local q = r.out and XG.QUEST_DEMAND[r.out]
    if q then GameTooltip:AddLine(C.orange .. "Demandé par " .. q[1] .. " quête(s) : " .. q[6] .. "|r", 1, 1, 1, true) end
    if e.bound then GameTooltip:AddLine(C.yellow .. "L'objet fabriqué est lié : il ne se vend qu'au marchand.|r", 1, 1, 1, true) end
    if e.sales then GameTooltip:AddLine(C.grey .. "Il s'en vend ~" .. XG.Num(e.sales, e.sales < 10 and 1 or 0) .. " par jour.|r") end
    if e.missing then GameTooltip:AddLine(C.orange .. "Certains composants n'ont jamais été vus à l'HV : scanne l'HV ou visite le marchand qui les vend.|r", 1, 1, 1, true) end
    if r.out then GameTooltip:AddLine(UI.ClickHint()) end
    if r.diff then GameTooltip:AddLine(C.grey .. "Difficulté : " .. (XG.DIFF_COLOR[r.diff] or "") .. (DIFF_TEXT[r.diff] or "?") .. "|r" .. C.grey .. (r.ups and r.ups > 1 and (" · " .. r.ups .. " points") or "") .. "|r") end
    GameTooltip:Show()
end

local function chip(parent, i)
    local b = P.chips[i]
    if b then return b end
    b = CreateFrame("Button", nil, parent)
    b:SetSize(150, 38)
    b.bg = UI.Tex(b, "BACKGROUND", 0.14, 0.16, 0.2, 1)
    b.bg:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(24, 24)
    b.icon:SetPoint("LEFT", 7, 0)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.name = UI.Text(b, 12, R.text)
    b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, 0)
    b.name:SetWidth(108)
    b.sub = UI.Text(b, 10, R.muted)
    b.sub:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 0)
    b.sub:SetWidth(108)
    b:SetPoint("TOPLEFT", (i - 1) * 156, -50)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(self.prof.name, 1, 1, 1)
        GameTooltip:AddLine(self.hint or "", 0.8, 0.83, 0.86, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self)
        if self.gather then XG:OpenFarm(self.gather) return end
        P.selected = self.prof.name
        XG:RefreshUI()
    end)
    P.chips[i] = b
    return b
end

XG:RegisterPage("prof", "Métiers", "Interface\\Icons\\Trade_BlackSmithing", function(f)
    local t = UI.Text(f, 15, R.text)
    t:SetPoint("TOPLEFT")
    t:SetText("Tes métiers")
    local s = UI.Text(f, 11, R.muted)
    s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
    s:SetWidth(680)
    s:SetWordWrap(true)
    s:SetText("Ouvre une fois la fenêtre de chaque métier : XbiGold retient tes recettes et calcule ce qui rapporte avec les prix de l'HV.")
    P.page = f

    P.seg = UI.Segmented(f, {
        {value = "profit", label = "Ce qui rapporte", w = 116},
        {value = "level", label = "Monter le métier", w = 124},
        {value = "learn", label = "Recettes à apprendre", w = 150},
    }, function(v) P.mode = v; XG:RefreshUI() end)
    P.seg:SetPoint("TOPLEFT", 0, -98)
    P.seg:Select("profit")
    P.info = UI.Text(f, 11, R.muted, "RIGHT")
    P.info:SetPoint("TOPRIGHT", 0, -104)

    local nameCol = {label = "Recette", width = "fill", icon = function(d) return d.r.out and XG.ItemIcon(d.r.out) or d.r.icon or 134400 end,
                     text = recipeLabel, sort = function(d) return d.r.name or "" end}
    local profitCol = {label = "Profit", width = 76, align = "RIGHT", text = function(d)
        if not d.e.profit then return C.grey .. "?|r" end
        return ((d.e.profit >= 0) and C.green or C.red) .. XG.Money(d.e.profit) .. "|r" .. (d.e.missing and (C.orange .. "?|r") or "") end,
        sort = function(d) return d.e.profit or -1e12 end}
    local salesCol = {label = "Ventes/j", width = 56, align = "RIGHT", text = function(d)
        return d.e.sales and ("~" .. XG.Num(d.e.sales, d.e.sales < 10 and 1 or 0)) or (C.grey .. "-|r") end, sort = function(d) return d.e.sales or -1 end}
    local bagCol = {label = "Faisable", width = 56, align = "RIGHT", text = function(d)
        return d.e.craftable > 0 and (C.green .. "x" .. d.e.craftable .. "|r") or (C.grey .. "0|r") end, sort = function(d) return d.e.craftable end}

    P.profit = UI.Table(f, {
        nameCol,
        {label = "Coût", width = 74, align = "RIGHT", text = function(d) return XG.Money(d.e.cost) .. (d.e.missing and (C.orange .. "+?|r") or "") end, sort = function(d) return d.e.cost end},
        {label = "Vente", width = 74, align = "RIGHT", text = function(d) return d.e.sellNet and XG.Money(d.e.sellNet) or (C.grey .. "?|r") end, sort = function(d) return d.e.sellNet or 0 end},
        profitCol,
        {label = "Marge", width = 48, align = "RIGHT", text = function(d) return d.e.margin and XG.Pct(d.e.margin) or "" end, sort = function(d) return d.e.margin or -1e9 end},
        salesCol, bagCol,
    }, {sortCol = 4, onEnter = recipeTooltip, onClick = function(_, d, button)
        if d.r.out then XG.RowClick(d.r.out, nil, button) end
    end})

    P.level = UI.Table(f, {
        {label = "Recette", width = "fill", icon = nameCol.icon, text = function(d) return (XG.DIFF_COLOR[d.r.diff] or "") .. (d.r.name or "?") .. "|r" end, sort = nameCol.sort},
        {label = "Points", width = 52, align = "CENTER", text = function(d) return (XG.DIFF_COLOR[d.r.diff] or "") .. (d.r.diff == 0 and (d.r.ups or 1) or (d.r.diff == 1 and "~1" or "peu")) .. "|r" end, sort = function(d) return -(d.r.diff or 9) end},
        {label = "Coût", width = 74, align = "RIGHT", text = function(d) return XG.Money(d.e.cost) .. (d.e.missing and (C.orange .. "+?|r") or "") end, sort = function(d) return d.e.cost end},
        {label = "Revente", width = 74, align = "RIGHT", text = function(d) return d.e.sellNet and XG.Money(d.e.sellNet) or (C.grey .. "-|r") end, sort = function(d) return d.e.sellNet or 0 end},
        {label = "Coût réel", width = 78, align = "RIGHT", text = function(d)
            local net = d.e.cost - (d.e.sellNet or 0)
            return net <= 0 and (C.green .. "gratuit|r") or XG.Money(net) end, sort = function(d) return -(d.e.cost - (d.e.sellNet or 0)) end},
        bagCol,
    }, {sortCol = 5, onEnter = recipeTooltip, onClick = function(_, d, button) if d.r.out then XG.RowClick(d.r.out, nil, button) end end})

    P.learn = UI.Table(f, {
        nameCol,
        {label = "Coût", width = 74, align = "RIGHT", text = function(d) return XG.Money(d.e.cost) end, sort = function(d) return d.e.cost end},
        {label = "Vente", width = 74, align = "RIGHT", text = function(d) return d.e.sellNet and XG.Money(d.e.sellNet) or (C.grey .. "?|r") end, sort = function(d) return d.e.sellNet or 0 end},
        profitCol, salesCol,
    }, {sortCol = 4, onEnter = recipeTooltip, onClick = function(_, d, button) if d.r.out then XG.RowClick(d.r.out, nil, button) end end})

    for _, tb in ipairs({P.profit, P.level, P.learn}) do
        tb:SetPoint("TOPLEFT", 0, -132)
        tb:SetPoint("BOTTOMRIGHT")
    end
end, function(f)
    -- Métiers connus : livre de sorts + recettes mémorisées
    local store = XG.cdb.profs or {}
    local profs, seen = {}, {}
    for _, kp in ipairs(XG:KnownProfessions()) do
        local rec = store[kp.name]
        profs[#profs + 1] = {name = kp.name, icon = kp.icon, level = kp.level, max = kp.max, skillLine = kp.skillLine, rec = rec}
        seen[kp.name] = true
    end
    for name, rec in pairs(store) do
        if not seen[name] then profs[#profs + 1] = {name = name, icon = rec.icon, level = rec.level, max = rec.max, skillLine = rec.skillLine, rec = rec} end
    end
    -- sélection par défaut : le premier métier d'artisanat analysé
    if not P.selected or not store[P.selected] then
        P.selected = nil
        for _, p in ipairs(profs) do if p.rec and not XG.GATHER_PROF[p.skillLine or 0] then P.selected = p.name break end end
    end
    for i, p in ipairs(profs) do
        if i > 4 then break end
        local b = chip(f, i)
        b.prof = p
        b.gather = XG.GATHER_PROF[p.skillLine or 0]
        b.icon:SetTexture(p.icon or 134400)
        b.name:SetText(p.name)
        b.sub:SetText((p.level and p.max) and (p.level .. " / " .. p.max) or "")
        local on = p.name == P.selected
        b.bg:SetColorTexture(on and 1 or 0.14, on and 0.78 or 0.16, on and 0.1 or 0.2, on and 0.25 or 1)
        if b.gather then
            b.hint = "Métier de récolte : clique pour voir ce qui se vend le mieux dans l'onglet À farmer."
            b.sub:SetText(b.sub:GetText() .. C.blue .. "  à farmer »|r")
        elseif p.rec then
            b.hint = "Analysé " .. XG.Ago(p.rec.t) .. ". Rouvre la fenêtre du métier pour mettre à jour."
        else
            b.hint = "Pas encore analysé : ouvre la fenêtre de ce métier une fois."
            b.sub:SetText(b.sub:GetText() .. C.orange .. "  à ouvrir|r")
        end
        b:Show()
    end
    for i = #profs + 1, #P.chips do P.chips[i]:Hide() end

    P.profit:SetShown(P.mode == "profit")
    P.level:SetShown(P.mode == "level")
    P.learn:SetShown(P.mode == "learn")

    local rec = P.selected and store[P.selected]
    local rows = {}
    if rec then
        for rid, r in pairs(rec.recipes or {}) do
            local keep
            if P.mode == "profit" then keep = r.learned and r.out ~= nil
            elseif P.mode == "level" then keep = r.learned and r.diff ~= nil and r.diff <= 1
            else keep = not r.learned and r.out ~= nil end
            if keep then rows[#rows + 1] = {rid = rid, r = r, e = XG:RecipeEval(r)} end
        end
        P.info:SetText(rec.name .. ((rec.level and rec.max) and (" " .. rec.level .. "/" .. rec.max) or "") .. "  ·  analysé " .. XG.Ago(rec.t))
    else
        P.info:SetText("")
    end
    local empty
    if not rec then
        empty = "Ouvre la fenêtre d'un métier d'artisanat (Couture, Alchimie, Forge...) :\nXbiGold calculera tout seul ce qui rapporte."
    elseif P.mode == "level" then
        empty = "Aucune recette orange ou jaune : tu dois apprendre de nouvelles recettes chez ton maître."
    elseif P.mode == "learn" then
        empty = "Aucune recette non apprise listée par le jeu pour ce métier."
    else
        empty = "Aucune recette avec un objet à vendre."
    end
    local tb = P.mode == "profit" and P.profit or (P.mode == "level" and P.level or P.learn)
    tb:SetData(rows, empty)
end, 35)
