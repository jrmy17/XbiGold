-- XbiGold : icône sur la minicarte (clic gauche : fenêtre, clic droit : session de farm, glisser : déplacer)
local _, XG = ...

local atan2 = math.atan2 or math.atan
local button

local function place()
    if not button then return end
    local angle = math.rad(XG.S.minimapAngle or 200)
    local r = (Minimap:GetWidth() or 140) / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function onDrag()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    XG.S.minimapAngle = math.deg(atan2(py / scale - my, px / scale - mx)) % 360
    place()
end

local function tooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(XG.NAME)
    local deals = XG.M and XG.M.deals or {}
    local sum = 0
    for _, d in ipairs(deals) do sum = sum + d.profit end
    GameTooltip:AddDoubleLine("Bonnes affaires", #deals .. "  (" .. XG.Money(sum) .. ")", 0.8, 0.83, 0.86, 1, 1, 1)
    if XG.cdb and XG.cdb.session then
        local _, gph = XG:SessionTotals()
        GameTooltip:AddDoubleLine("Session de farm", XG.Money(gph) .. " /h", 0.8, 0.83, 0.86, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Clic gauche", "ouvrir la fenêtre", 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Clic droit", "démarrer / mettre en pause le farm", 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Glisser", "déplacer l'icône", 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end

function XG:CreateMinimapButton()
    if button or not Minimap then return end
    button = CreateFrame("Button", "XbiGoldMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", 7, -6)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    button:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then
            if XG:SessionRunning() then XG:PauseSession() else XG:StartSession() end
            tooltip(self)
        else
            XG:Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDrag) end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", tooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    place()
    XG:UpdateMinimapButton()
end

function XG:UpdateMinimapButton()
    if not button then return end
    button:SetShown(XG.S.minimap)
end
