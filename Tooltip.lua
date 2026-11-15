-- XbiGold : prix dans les infobulles des objets
local _, XG = ...

local floor = math.floor
local C = XG.C

local function trendText(t)
    if not t then return "" end
    if t >= 0.08 then return "  " .. C.green .. "+" .. XG.Num(t * 100) .. " %|r" end
    if t <= -0.08 then return "  " .. C.red .. "-" .. XG.Num(-t * 100) .. " %|r" end
    return "  " .. C.grey .. "stable|r"
end

local function addLines(tt, link, count)
    if not XG.S or not XG.S.tooltip then return end
    if XG.S.tooltipShift and not IsShiftKeyDown() then return end
    local key, id = XG.KeyFromLink(link)
    if not id then return end
    count = (count and count > 1) and count or 1

    local v, src, ndays = XG:Value(key)
    local it = XG:Item(key) or (key ~= tostring(id) and XG:Item(id))
    local info = XG.ItemInfo(id)
    local q = XG.QUEST_DEMAND and XG.QUEST_DEMAND[id]
    if not v and not (info and info.sell and info.sell > 0) and not q then return end

    tt:AddLine(" ")
    tt:AddLine(XG.NAME)
    if v then
        local label = "Valeur HV" .. (src ~= "XbiGold" and (C.grey .. " (" .. src .. ")|r") or "")
        local right = XG.Money(v * count) .. (count > 1 and (C.grey .. "  (" .. XG.Money(v) .. " pièce)|r") or "")
        tt:AddDoubleLine(label .. trendText(XG:Trend(key)), right, 0.85, 0.88, 0.92, 1, 1, 1)
        if it and it.t then
            local supply = (it.q or 0) == 0 and (C.orange .. "aucune en vente !|r")
                or (XG.Num(it.q) .. " en vente, " .. "min " .. XG.Money(it.l))
            tt:AddDoubleLine(C.grey .. "  " .. XG.Ago(it.t) .. "|r", supply, 1, 1, 1, 0.8, 0.83, 0.86)
        end
        local sales = XG:SalesPerDay(key)
        if sales and sales > 0 then
            tt:AddDoubleLine(C.grey .. "  Ventes estimées|r", "~ " .. XG.Num(sales, sales < 10 and 1 or 0) .. " / jour", 1, 1, 1, 0.8, 0.83, 0.86)
        end
    end
    if info and info.sell and info.sell > 0 then
        tt:AddDoubleLine("Marchand", XG.Money(info.sell * count), 0.85, 0.88, 0.92, 1, 1, 1)
    end
    -- Conseil
    if v and info then
        local where = XG:SellAdvice(key, id, count, info.bind == 1)
        if where == "hv" then
            tt:AddLine(C.green .. "» À vendre à l'HV|r")
        elseif where == "marchand" and info.sell > 0 then
            tt:AddLine(C.yellow .. "» Plus rentable au marchand|r")
        end
    end
    -- Revente de marchand connue
    local vend = XG.db.vendors[id]
    if vend and vend.c and v then
        local profit = XG:VendorFlip(id, vend.c)
        if profit and profit > 0 then
            tt:AddLine(C.blue .. "Vendu par un PNJ " .. XG.Money(vend.c) .. " : revente +" .. XG.Money(profit) .. "|r")
        end
    end
    if v then tt:AddLine(C.grey .. "Alt+clic : courbe des prix et meilleures heures|r") end
    if q then
        local fac = q[5] == 1 and " (Alliance)" or (q[5] == 2 and " (Horde)" or "")
        local lv = q[3] == q[4] and ("niv. " .. q[3]) or ("niv. " .. q[3] .. "-" .. q[4])
        tt:AddLine(C.orange .. "Objet de quête|r" .. C.grey .. " : " .. q[1] .. " quête(s), " .. lv .. fac .. "|r", 1, 1, 1, true)
    end
end

local function hook()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            if tt ~= GameTooltip and tt ~= ItemRefTooltip and tt ~= GameTooltipTooltip then
                if not (tt.GetName and tt:GetName() and tt:GetName():find("ShoppingTooltip")) then return end
            end
            local link
            if tt.GetItem then link = select(2, tt:GetItem()) end
            if not link and data and data.hyperlink then link = data.hyperlink end
            if not link and data and data.id then link = "item:" .. data.id end
            if not link then return end
            local count
            local owner = tt.GetOwner and tt:GetOwner()
            if owner and owner.count then count = owner.count end
            pcall(addLines, tt, link, count)
        end)
    else
        GameTooltip:HookScript("OnTooltipSetItem", function(tt)
            local _, link = tt:GetItem()
            if link then pcall(addLines, tt, link) end
        end)
    end
end

function XG:HookTooltips()
    if XG.tooltipHooked then return end
    XG.tooltipHooked = true
    hook()
end
