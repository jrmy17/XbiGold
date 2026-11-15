-- XbiGold : reventes de marchand (acheter chez un PNJ, revendre à l'HV) + mémoire des marchands visités
local _, XG = ...

local floor, max = math.floor, math.max

XG.merchant = nil -- marchand ouvert : {npc, zone, items = {...}}

local function merchantItem(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local r = C_MerchantFrame.GetItemInfo(i)
        if r then return r.price, r.stackCount, r.numAvailable, r.hasExtendedCost, r.isPurchasable end
        return nil
    end
    local _, _, price, stack, avail, purchasable, _, ext = GetMerchantItemInfo(i)
    return price, stack, avail, ext, purchasable
end

-- Analyse d'un objet vendu par un PNJ : bénéfice par unité à la revente à l'HV
function XG:VendorFlip(id, unitCost)
    local v, src = XG:Value(id)
    if not v or unitCost <= 0 then return nil end
    local net = v * (1 - XG.AH_CUT)
    local profit = net - unitCost
    if profit <= 0 then return nil end
    return profit, profit / unitCost, v, src
end

function XG:ScanMerchant()
    local n = GetMerchantNumItems and GetMerchantNumItems() or 0
    if n == 0 then return end
    local npc = UnitName("npc") or "?"
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local x, y
    if mapID and C_Map.GetPlayerMapPosition then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then x, y = pos:GetXY() end
    end
    local m = {npc = npc, zone = zone, items = {}}
    local now = time()
    for i = 1, n do
        local price, stack, avail, ext, purchasable = merchantItem(i)
        local link = GetMerchantItemLink(i)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id and price and price > 0 and not ext then
            stack = (stack and stack > 0) and stack or 1
            local unit = price / stack
            -- mémorise le marchand (les prix des PNJ sont les mêmes pour tout le monde)
            local rec = XG.db.vendors[id] or {v = {}}
            rec.c = rec.c and math.min(rec.c, unit) or unit
            rec.v = rec.v or {}
            rec.v[npc] = {z = zone, m = mapID, x = x and floor(x * 1000) / 10, y = y and floor(y * 1000) / 10,
                          lim = (avail and avail > 0) and avail or nil, t = now, f = XG.PlayerFaction()}
            XG.db.vendors[id] = rec
            local profit, margin, v = XG:VendorFlip(id, unit)
            m.items[#m.items + 1] = {index = i, id = id, unit = unit, stack = stack, avail = avail or -1,
                                     profit = profit, margin = margin, value = v}
        end
    end
    XG.merchant = m
    if XG.RefreshUI then XG:RefreshUI() end
end

-- Achète au marchand ouvert (respecte la taille de pile et le stock)
-- Achète un lot au marchand ouvert (1 clic = 1 lot, comme un clic droit sur l'objet)
function XG:BuyFromMerchant(entry)
    if not XG.merchant or not entry or not entry.index then return end
    BuyMerchantItem(entry.index)
end

------------------------------------------------------------------------
-- Bénéfice affiché sur les objets de la fenêtre du marchand
------------------------------------------------------------------------
local labels = {}
local function updateOverlay()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    local onBuyTab = (MerchantFrame.selectedTab or 1) == 1
    for i = 1, perPage do
        local btn = _G["MerchantItem" .. i .. "ItemButton"]
        if btn then
            local fs = labels[i]
            if not fs then
                local holder = _G["MerchantItem" .. i] or btn
                fs = holder:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                fs:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 3)
                labels[i] = fs
            end
            fs:Hide()
            if onBuyTab and XG.S.merchantOverlay then
                local index = ((MerchantFrame.page or 1) - 1) * perPage + i
                local price, stack, _, ext = merchantItem(index)
                local link = GetMerchantItemLink(index)
                local id = link and tonumber(link:match("item:(%d+)"))
                if id and price and price > 0 and not ext then
                    local unit = price / math.max(1, stack or 1)
                    local profit, margin = XG:VendorFlip(id, unit)
                    if profit and profit >= 50 and margin >= XG.S.minMargin then
                        fs:SetText(XG.C.green .. "+" .. XG.Money(profit * math.max(1, stack or 1), true) .. "|r")
                        fs:Show()
                    end
                end
            end
        end
    end
end

local f = CreateFrame("Frame")
XG.Reg(f, "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED")
f:SetScript("OnEvent", function(_, event)
    if not XG.M then return end
    if event == "MERCHANT_CLOSED" then
        XG.merchant = nil
        if XG.RefreshUI then XG:RefreshUI() end
        return
    end
    XG:ScanMerchant()
    updateOverlay()
end)

if MerchantFrame_UpdateMerchantInfo then
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function() pcall(updateOverlay) end)
end
