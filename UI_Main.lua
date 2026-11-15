-- XbiGold : fenêtre principale, navigation, fenêtre d'achat, bandeau de session
local _, XG = ...

local UI, R, C = XG.UI, XG.RGB, XG.C
local W, H, NAV_W, HEAD_H = 900, 560, 168, 54

XG.pages = {}
XG.pageOrder = {}

-- Les onglets s'enregistrent ici (UI_Tabs.lua)
function XG:RegisterPage(id, label, icon, build, refresh, order)
    XG.pages[id] = {id = id, label = label, icon = icon, build = build, refresh = refresh,
                    order = order or (#XG.pageOrder + 1) * 10}
    table.insert(XG.pageOrder, id)
    table.sort(XG.pageOrder, function(a, b) return XG.pages[a].order < XG.pages[b].order end)
end

local main

local function navButton(parent, page, y)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(NAV_W - 16, 34)
    b:SetPoint("TOPLEFT", 8, y)
    b.bg = UI.Tex(b, "BACKGROUND", 1, 1, 1, 0)
    b.bg:SetAllPoints()
    b.bar = UI.Tex(b, "ARTWORK", 1, 0.78, 0.1, 1)
    b.bar:SetPoint("TOPLEFT")
    b.bar:SetPoint("BOTTOMLEFT")
    b.bar:SetWidth(3)
    b.bar:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18)
    b.icon:SetPoint("LEFT", 12, 0)
    b.icon:SetTexture(page.icon)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.text = UI.Text(b, 12, R.text)
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
    b.text:SetText(page.label)
    b.badge = UI.Text(b, 10, {0.08, 0.07, 0.04}, "CENTER")
    b.badgeBg = UI.Tex(b, "ARTWORK", 1, 0.78, 0.1, 1)
    b.badgeBg:SetSize(26, 16)
    b.badgeBg:SetPoint("RIGHT", -8, 0)
    b.badge:SetPoint("CENTER", b.badgeBg)
    b.badge:SetDrawLayer("OVERLAY")
    b.badgeBg:Hide()
    b:SetScript("OnEnter", function(self) if main.current ~= page.id then self.bg:SetColorTexture(1, 1, 1, 0.04) end end)
    b:SetScript("OnLeave", function(self) if main.current ~= page.id then self.bg:SetColorTexture(1, 1, 1, 0) end end)
    b:SetScript("OnClick", function() XG:ShowPage(page.id) end)
    function b:SetBadge(n)
        if n and n > 0 then
            self.badge:SetText(n > 99 and "99+" or n)
            self.badgeBg:Show()
            self.badge:Show()
        else
            self.badgeBg:Hide()
            self.badge:Hide()
        end
    end
    b:SetBadge(nil)
    return b
end

function XG:CreateMain()
    if main then return main end
    main = CreateFrame("Frame", "XbiGoldFrame", UIParent)
    main:SetSize(W, H)
    if XG.db.pos then
        main:SetPoint(XG.db.pos[1], UIParent, XG.db.pos[2], XG.db.pos[3], XG.db.pos[4])
    else
        main:SetPoint("CENTER")
    end
    main:SetFrameStrata("HIGH")
    main:SetToplevel(true)
    main:SetClampedToScreen(true)
    main:SetMovable(true)
    main:EnableMouse(true)
    main:RegisterForDrag("LeftButton")
    main:SetScript("OnDragStart", main.StartMoving)
    main:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        XG.db.pos = {p, rp, x, y}
    end)
    main:SetScale(XG.S.scale or 1)
    UI.Fill(main, R.bg, 0.97)
    UI.Border(main, 1, 1, 1, 0.07)
    tinsert(UISpecialFrames, "XbiGoldFrame")
    main:Hide()

    -- En-tête
    local head = CreateFrame("Frame", nil, main)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD_H)
    UI.Fill(head, R.panel)
    local logoBg = UI.Tex(head, "ARTWORK", 1, 0.78, 0.1, 1)
    logoBg:SetSize(30, 30)
    logoBg:SetPoint("LEFT", 14, 0)
    local logo = head:CreateTexture(nil, "OVERLAY")
    logo:SetSize(26, 26)
    logo:SetPoint("CENTER", logoBg)
    logo:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
    logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local title = UI.Text(head, 17, R.text)
    title:SetPoint("TOPLEFT", logoBg, "TOPRIGHT", 10, 1)
    title:SetText(XG.NAME)
    main.status = UI.Text(head, 11, R.muted)
    main.status:SetPoint("BOTTOMLEFT", logoBg, "BOTTOMRIGHT", 10, 0)

    local close = UI.Button(head, "X", 28, 28, "ghost", function() main:Hide() end)
    close:SetPoint("RIGHT", -12, 0)
    main.scanBtn = UI.Button(head, "Scanner l'HV", 130, 28, "primary", function() XG:StartScan() end)
    main.scanBtn:SetPoint("RIGHT", close, "LEFT", -8, 0)
    main.scanBar = CreateFrame("StatusBar", nil, head)
    main.scanBar:SetPoint("BOTTOMLEFT")
    main.scanBar:SetPoint("BOTTOMRIGHT")
    main.scanBar:SetHeight(2)
    main.scanBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    main.scanBar:SetStatusBarColor(1, 0.78, 0.1)
    main.scanBar:SetMinMaxValues(0, 1)
    main.scanBar:Hide()

    -- Navigation
    local nav = CreateFrame("Frame", nil, main)
    nav:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
    nav:SetPoint("BOTTOMLEFT")
    nav:SetWidth(NAV_W)
    UI.Fill(nav, R.panel)
    local sep = UI.Tex(nav, "BORDER", 1, 1, 1, 0.06)
    sep:SetPoint("TOPRIGHT")
    sep:SetPoint("BOTTOMRIGHT")
    sep:SetWidth(1)
    main.nav = {}
    for i, id in ipairs(XG.pageOrder) do
        main.nav[id] = navButton(nav, XG.pages[id], -12 - (i - 1) * 38)
    end
    local ver = UI.Text(nav, 10, R.muted, "CENTER")
    ver:SetPoint("BOTTOM", 0, 10)
    ver:SetText("v" .. ((C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)("XbiGold", "Version") or "1") .. "  ·  /xg")

    -- Contenu
    local content = CreateFrame("Frame", nil, main)
    content:SetPoint("TOPLEFT", head, "BOTTOMLEFT", NAV_W + 16, -14)
    content:SetPoint("BOTTOMRIGHT", -16, 14)
    main.content = content

    for _, id in ipairs(XG.pageOrder) do
        local page = XG.pages[id]
        local f = CreateFrame("Frame", nil, content)
        f:SetAllPoints()
        f:Hide()
        page.frame = f
        page.build(f)
    end

    main:SetScript("OnShow", function() XG:RefreshUI() end)
    XG:ShowPage(XG.cdb.lastPage or "home")
    return main
end

function XG:ShowPage(id)
    if not XG.pages[id] then id = "home" end
    main.current = id
    XG.cdb.lastPage = id
    for pid, page in pairs(XG.pages) do
        page.frame:SetShown(pid == id)
        local b = main.nav[pid]
        if b then
            b.bar:SetShown(pid == id)
            b.bg:SetColorTexture(1, 1, 1, pid == id and 0.06 or 0)
            b.text:SetTextColor(pid == id and 1 or R.text[1], pid == id and 0.86 or R.text[2], pid == id and 0.3 or R.text[3])
        end
    end
    local p = XG.pages[id]
    if p.refresh then p.refresh(p.frame) end
end

function XG:Toggle()
    XG:CreateMain()
    if main:IsShown() then main:Hide() else main:Show() end
end

function XG:Open(page)
    XG:CreateMain()
    main:Show()
    if page then XG:ShowPage(page) end
end

function XG:UpdateHeader()
    if not main then return end
    local M = XG.M
    local txt = (GetRealmName() or "") .. " · " .. (XG.neutral and "HV neutre (15 %)" or (UnitFactionGroup("player") == "Horde" and "Horde" or "Alliance"))
    local shared = M.shared and M.shared.t or 0
    if shared > (M.lastScan or 0) then
        txt = txt .. "  ·  prix à jour " .. XG.Ago(shared) .. " (scan de " .. (M.shared.from or "?") .. ")"
    elseif (M.lastScan or 0) > 0 then
        txt = txt .. "  ·  dernier scan " .. XG.Ago(M.lastScan)
    else
        txt = txt .. "  ·  aucun scan pour l'instant"
    end
    txt = txt .. "  ·  " .. XG.Num(XG:CountItems()) .. " objets suivis"
    local n = 0
    for _, p in pairs(XG.peers or {}) do if p.sameMarket and time() - (p.seen or 0) < 3600 then n = n + 1 end end
    if n > 0 then txt = txt .. "  ·  " .. n .. " joueur(s) XbiGold" end
    main.status:SetText(txt)
    local b = main.scanBtn
    if XG.scan.running then
        b:SetText("Scan... " .. math.floor((XG.scan.progress or 0) * 100) .. " %")
        b:Disable()
        main.scanBar:Show()
        main.scanBar:SetValue(XG.scan.progress or 0)
    else
        main.scanBar:Hide()
        if not XG.ahOpen then
            b:SetText("Scanner l'HV")
            b:Disable()
            b.tip = "Ouvre l'hôtel des ventes pour lancer un scan complet."
        else
            local left = XG:ScanCooldown()
            if left > 0 then
                b:SetText("Scan dans " .. XG.Duration(left))
                b:Disable()
                b.tip = "Blizzard autorise un scan complet toutes les 15 minutes."
            else
                b:SetText("Scanner l'HV")
                b:Enable()
                b.tip = "Récupère toutes les annonces de l'HV en une fois (quelques secondes)."
            end
        end
    end
    if main.nav.deals then main.nav.deals:SetBadge(#(M.deals or {})) end
end

function XG:RefreshUI()
    if not main or not main:IsShown() then return end
    XG:UpdateHeader()
    local p = XG.pages[main.current]
    if p and p.refresh then p.refresh(p.frame) end
end

function XG:OnScanProgress() XG:UpdateHeader() end
function XG:OnScanDone() XG:RefreshUI() end
function XG:OnItemInfo() XG:RefreshUI() end

-- À l'ouverture de l'HV : la fenêtre se place à côté
function XG:OnAHShow()
    if XG.S.openWithAH then
        XG:CreateMain()
        main:Show()
        -- la fenêtre de l'HV de Blizzard se charge juste après l'événement
        C_Timer.After(0.2, function()
            if AuctionHouseFrame and AuctionHouseFrame:IsShown() and not XG.db.pos then
                main:ClearAllPoints()
                main:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 12, 0)
            end
        end)
    end
    XG:RefreshUI()
    if XG.UpdateItemFrameAH then XG:UpdateItemFrameAH() end
end
function XG:OnAHClose()
    XG:RefreshUI()
    if XG.UpdateItemFrameAH then XG:UpdateItemFrameAH() end
end

C_Timer.NewTicker(1, function()
    if main and main:IsShown() then XG:UpdateHeader() end
end)

------------------------------------------------------------------------
-- Fenêtre d'achat
------------------------------------------------------------------------
local pop
local function createPopup()
    pop = CreateFrame("Frame", "XbiGoldBuyPopup", UIParent)
    pop:SetSize(360, 196)
    pop:SetFrameStrata("DIALOG")
    pop:SetPoint("CENTER", 0, 120)
    pop:EnableMouse(true)
    pop:SetMovable(true)
    pop:RegisterForDrag("LeftButton")
    pop:SetScript("OnDragStart", pop.StartMoving)
    pop:SetScript("OnDragStop", pop.StopMovingOrSizing)
    UI.Fill(pop, R.panel, 0.98)
    UI.Border(pop, 1, 0.78, 0.1, 0.5)
    pop.icon = pop:CreateTexture(nil, "ARTWORK")
    pop.icon:SetSize(36, 36)
    pop.icon:SetPoint("TOPLEFT", 16, -16)
    pop.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pop.name = UI.Text(pop, 14, R.text)
    pop.name:SetPoint("TOPLEFT", pop.icon, "TOPRIGHT", 10, -2)
    pop.name:SetWidth(280)
    pop.sub = UI.Text(pop, 11, R.muted)
    pop.sub:SetPoint("TOPLEFT", pop.name, "BOTTOMLEFT", 0, -4)
    pop.lines = UI.Text(pop, 12, R.text)
    pop.lines:SetPoint("TOPLEFT", pop.icon, "BOTTOMLEFT", 0, -14)
    pop.lines:SetWidth(328)
    pop.lines:SetWordWrap(true)
    pop.lines:SetSpacing(4)
    pop.action = UI.Button(pop, "Acheter", 160, 30, "primary")
    pop.action:SetPoint("BOTTOMRIGHT", -16, 14)
    pop.cancel = UI.Button(pop, "Fermer", 100, 30, "ghost", function() XG:CancelBuy() end)
    pop.cancel:SetPoint("RIGHT", pop.action, "LEFT", -8, 0)
    tinsert(UISpecialFrames, "XbiGoldBuyPopup")
    pop:SetScript("OnHide", function() if XG.buy and XG.buy.stage ~= "price" then XG.buy = nil end end)
end

function XG:ShowBuyPopup()
    if not pop then createPopup() end
    pop:Show()
    XG:UpdateBuyPopup()
end

function XG:HideBuyPopup()
    if pop then pop:Hide() end
end

function XG:UpdateBuyPopup()
    local b = XG.buy
    if not pop or not b then return end
    local d = b.deal
    local info = XG.ItemInfo(d.id)
    pop.icon:SetTexture(XG.ItemIcon(d.id))
    pop.name:SetText((info and (XG.QualityColor(info.quality) .. info.name .. "|r")) or ("Objet " .. d.id))
    pop.sub:SetText(d.type == "vendor" and "À racheter puis revendre au marchand" or "À racheter puis revendre à l'HV")
    local lines = {}
    local st = b.stage
    pop.action:Show()
    pop.action:Enable()
    if st == "search" then
        lines[#lines + 1] = C.grey .. (b.msg or "Recherche...") .. "|r"
        pop.action:SetText("Patiente...")
        pop.action:Disable()
    elseif st == "ready" then
        local unit = b.cost / math.max(1, b.qty)
        local resale = d.type == "vendor" and d.resale * b.qty or d.resale * b.qty * (1 - XG.AH_CUT)
        lines[#lines + 1] = ("Acheter %s%d|r × %s = %s"):format(C.white, b.qty, XG.Money(unit), XG.Money(b.cost))
        lines[#lines + 1] = ("Revente %s : %s  »  %sbénéfice %s|r"):format(d.type == "vendor" and "marchand" or "HV",
            XG.Money(resale), C.green, XG.Money(resale - b.cost))
        if d.type ~= "vendor" then
            lines[#lines + 1] = C.grey .. "Prix de revente conseillé : " .. XG.Money(d.resale) .. " l'unité.|r"
        end
        pop.action:SetText("Acheter")
        pop.action:SetScript("OnClick", function() XG:BuyClick() end)
    elseif st == "confirm" then
        lines[#lines + 1] = ("Prix exact du serveur : %s%d|r pour %s (%s l'unité)"):format(C.white, b.qty,
            XG.Money(b.serverTotal), XG.Money(b.serverUnit))
        lines[#lines + 1] = C.grey .. "Clique pour confirmer l'achat.|r"
        pop.action:SetText("Confirmer")
        pop.action:SetScript("OnClick", function() XG:ConfirmClick() end)
    elseif st == "price" then
        lines[#lines + 1] = C.grey .. (b.msg or "...") .. "|r"
        pop.action:SetText("Patiente...")
        pop.action:Disable()
    elseif st == "done" then
        lines[#lines + 1] = C.green .. (b.msg or "Acheté !") .. "|r"
        lines[#lines + 1] = ("Total : %d acheté(s) pour %s. Revends à %s l'unité."):format(b.bought, XG.Money(b.spent), XG.Money(d.resale))
        pop.action:Hide()
    elseif st == "fail" then
        lines[#lines + 1] = C.red .. (b.msg or "Échec.") .. "|r"
        if b.bought > 0 then lines[#lines + 1] = ("Déjà acheté : %d pour %s."):format(b.bought, XG.Money(b.spent)) end
        pop.action:SetText("Réessayer")
        pop.action:SetScript("OnClick", function() XG:BuyDeal(d) end)
    end
    pop.lines:SetText(table.concat(lines, "\n"))
end

------------------------------------------------------------------------
-- Bandeau de session de farm
------------------------------------------------------------------------
function XG:CreateHUD()
    local h = CreateFrame("Frame", "XbiGoldHUD", UIParent)
    h:SetSize(300, 30)
    local pos = XG.db.hudPos
    if pos then h:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else h:SetPoint("TOP", 0, -120) end
    h:SetMovable(true)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", h.StartMoving)
    h:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        XG.db.hudPos = {p, rp, x, y}
    end)
    UI.Fill(h, R.bg, 0.88)
    UI.Border(h, 1, 0.78, 0.1, 0.35)
    local icon = h:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 6, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    h.time = UI.Text(h, 11, R.muted)
    h.time:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    h.total = UI.Text(h, 12, R.text)
    h.total:SetPoint("LEFT", h.time, "RIGHT", 10, 0)
    h.gph = UI.Text(h, 12, {1, 0.82, 0})
    h.gph:SetPoint("LEFT", h.total, "RIGHT", 10, 0)
    h.toggle = UI.Button(h, "Pause", 64, 20, "ghost", function()
        if XG:SessionRunning() then XG:PauseSession() else XG:StartSession() end
    end)
    h.toggle:SetPoint("RIGHT", -5, 0)
    h:SetScript("OnMouseUp", function(_, btn) if btn == "RightButton" then XG:Open("session") end end)
    -- la largeur suit le contenu
    h:SetScript("OnUpdate", function(self, el)
        self.e = (self.e or 0) + el
        if self.e < 0.5 then return end
        self.e = 0
        local w = 6 + 18 + 6 + self.time:GetStringWidth() + 10 + self.total:GetStringWidth() + 10 + self.gph:GetStringWidth() + 12 + 64 + 5
        self:SetWidth(math.max(240, w))
    end)
    return h
end
