-- XbiGold : achat d'une bonne affaire (2 clics : vérifier le prix, puis confirmer)
local _, XG = ...

local floor, min = math.floor, math.min
local PRICE_SORT = {sortOrder = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0, reverseSort = false}

-- État de l'achat en cours
-- stage : "search" (recherche) -> "ready" (prêt à acheter) -> "price" (prix demandé) -> "confirm" -> "done"/"fail"
XG.buy = nil

local function setStage(stage, msg)
    if not XG.buy then return end
    XG.buy.stage, XG.buy.msg = stage, msg
    if XG.UpdateBuyPopup then XG:UpdateBuyPopup() end
end

local function itemKeyFor(deal)
    local id = deal.id
    local suffix = tostring(deal.key):match(":(%-?%d+)$")
    if suffix and C_AuctionHouse.MakeItemKey then
        local info = XG.ItemInfo(id)
        return C_AuctionHouse.MakeItemKey(id, info and info.ilvl or 0, tonumber(suffix))
    end
    return C_AuctionHouse.MakeItemKey(id)
end

local function sendSearch()
    local b = XG.buy
    if not b then return end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        C_Timer.After(0.5, sendSearch)
        return
    end
    b.itemKey = b.itemKey or itemKeyFor(b.deal)
    C_AuctionHouse.SendSearchQuery(b.itemKey, {PRICE_SORT}, true)
    -- si aucune réponse (objet introuvable), on prévient
    local token = {}
    b.token = token
    C_Timer.After(6, function()
        if XG.buy and XG.buy.token == token and XG.buy.stage == "search" then
            if b.deal.suffixRetry == nil and tostring(b.deal.key):find(":") then
                b.deal.suffixRetry = true
                b.itemKey = C_AuctionHouse.MakeItemKey(b.deal.id)
                sendSearch()
            else
                setStage("fail", "Pas de réponse de l'HV. L'annonce a peut-être déjà été achetée.")
            end
        end
    end)
end

function XG:BuyDeal(deal)
    if not XG.ahOpen then
        XG.Print("ouvre l'hôtel des ventes pour acheter.")
        return
    end
    XG.buy = {deal = deal, stage = "search", bought = 0, spent = 0}
    if XG.ShowBuyPopup then XG:ShowBuyPopup() end
    setStage("search", "Vérification des prix actuels...")
    sendSearch()
end

function XG:CancelBuy()
    if XG.buy and XG.buy.stage == "confirm" and XG.buy.commodity and C_AuctionHouse.CancelCommoditiesPurchase then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    end
    XG.buy = nil
    if XG.HideBuyPopup then XG:HideBuyPopup() end
end

-- Résultats d'une recherche d'objet empilable (commodité)
function XG:Buyer_OnCommodityResults(itemID)
    local b = XG.buy
    if not b or b.deal.id ~= itemID or (b.stage ~= "search" and b.stage ~= "ready") then return end
    b.commodity = true
    local maxUnit = b.deal.maxUnit
    local avail, cost = 0, 0
    local want = b.deal.qty - b.bought
    for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) do
        local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if not r or not r.unitPrice or r.unitPrice > maxUnit then break end
        local q = r.quantity or 0
        if r.containsOwnerItem and r.numOwnerItems then q = q - r.numOwnerItems end -- on n'achète pas ses propres annonces
        if q > 0 then
            local take = min(q, want - avail)
            avail, cost = avail + take, cost + take * r.unitPrice
            if avail >= want then break end
        end
    end
    if avail <= 0 then
        setStage("fail", "Trop tard : il n'y a plus d'annonce à ce prix.")
        return
    end
    b.qty, b.cost = avail, cost
    setStage("ready", nil)
end

-- Résultats d'une recherche d'objet non empilable (équipement...)
function XG:Buyer_OnItemResults(itemKey)
    local b = XG.buy
    if not b or not itemKey or itemKey.itemID ~= b.deal.id or (b.stage ~= "search" and b.stage ~= "ready") then return end
    b.commodity = false
    local wantKey = tostring(b.deal.key)
    local found
    for i = 1, C_AuctionHouse.GetNumItemSearchResults(itemKey) do
        local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if r and r.buyoutAmount and r.buyoutAmount > 0 and r.buyoutAmount <= b.deal.maxUnit and not r.containsOwnerItem then
            local k = r.itemLink and XG.KeyFromLink(r.itemLink) or tostring(itemKey.itemID)
            if not wantKey:find(":") or k == wantKey then
                found = r
                break
            end
        end
    end
    if not found then
        setStage("fail", "Trop tard : il n'y a plus d'annonce à ce prix.")
        return
    end
    b.auctionID, b.qty, b.cost = found.auctionID, 1, found.buyoutAmount
    setStage("ready", nil)
end

-- 1er clic : acheter
function XG:BuyClick()
    local b = XG.buy
    if not b or b.stage ~= "ready" then return end
    if b.commodity then
        C_AuctionHouse.StartCommoditiesPurchase(b.deal.id, b.qty)
        setStage("price", "Le serveur calcule le prix exact...")
    else
        C_AuctionHouse.PlaceBid(b.auctionID, b.cost)
        setStage("price", "Achat en cours...")
    end
end

-- 2e clic (commodités) : confirmer au prix annoncé par le serveur
function XG:ConfirmClick()
    local b = XG.buy
    if not b or b.stage ~= "confirm" then return end
    C_AuctionHouse.ConfirmCommoditiesPurchase(b.deal.id, b.qty)
    setStage("price", "Achat en cours...")
end

local function done(ok, msg)
    local b = XG.buy
    if not b then return end
    if ok then
        b.bought = b.bought + (b.qty or 0)
        b.spent = b.spent + (b.serverTotal or b.cost or 0)
        -- met à jour l'affaire dans la liste
        local d = b.deal
        d.qty = d.qty - (b.qty or 0)
        d.bought = (d.bought or 0) + (b.qty or 0)
        if d.qty <= 0 then
            for i, x in ipairs(XG.M.deals) do if x == d then table.remove(XG.M.deals, i) break end end
        end
        XG.cdb.purchases = XG.cdb.purchases or {}
        table.insert(XG.cdb.purchases, 1, {id = d.id, key = d.key, qty = b.qty, cost = b.serverTotal or b.cost, resale = d.resale, t = time()})
        while #XG.cdb.purchases > 100 do table.remove(XG.cdb.purchases) end
        if d.qty > 0 and not b.commodity then
            -- objet non empilable : on cherche l'annonce suivante
            b.stage = "search"
            setStage("search", "Acheté ! Recherche de l'annonce suivante...")
            C_Timer.After(0.3, sendSearch)
        else
            setStage("done", msg or "Acheté !")
        end
        if XG.RefreshUI then XG:RefreshUI() end
    else
        setStage("fail", msg or "L'achat a échoué.")
    end
end

local f = CreateFrame("Frame")
XG.Reg(f, "COMMODITY_PRICE_UPDATED")
XG.Reg(f, "COMMODITY_PRICE_UNAVAILABLE")
XG.Reg(f, "COMMODITY_PURCHASE_SUCCEEDED")
XG.Reg(f, "COMMODITY_PURCHASE_FAILED")
XG.Reg(f, "AUCTION_HOUSE_PURCHASE_COMPLETED")
XG.Reg(f, "AUCTION_HOUSE_SHOW_ERROR")
XG.Reg(f, "AUCTION_HOUSE_CLOSED")
f:SetScript("OnEvent", function(_, event, a, b2)
    local b = XG.buy
    if not b then return end
    if event == "COMMODITY_PRICE_UPDATED" and b.stage == "price" and b.commodity then
        local unit, totalPrice = a, b2
        b.serverUnit, b.serverTotal = unit, totalPrice
        -- garde-fou : quelqu'un a acheté avant nous et le prix a monté
        if unit and unit > b.deal.maxUnit * 1.02 + 1 then
            pcall(C_AuctionHouse.CancelCommoditiesPurchase)
            setStage("fail", ("Le prix a monté (%s l'unité) : achat annulé pour te protéger."):format(XG.Money(unit)))
        else
            setStage("confirm", nil)
        end
    elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
        setStage("fail", "Prix indisponible : les annonces ont changé.")
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        done(true)
    elseif event == "COMMODITY_PURCHASE_FAILED" then
        done(false, "Achat refusé par le serveur (or insuffisant ou annonces parties).")
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" and not b.commodity then
        done(true)
    elseif event == "AUCTION_HOUSE_SHOW_ERROR" and b.stage == "price" then
        done(false, "L'HV a refusé l'achat.")
    elseif event == "AUCTION_HOUSE_CLOSED" then
        XG:CancelBuy()
    end
end)

------------------------------------------------------------------------
-- Chercher un objet dans l'HV de Blizzard (sans changer de page nous-mêmes :
-- si un addon change la page de l'HV, le jeu bloque ensuite certains clics)
------------------------------------------------------------------------
function XG:SearchAH(id, tries)
    if not XG.ahOpen then
        XG.Print("ouvre l'hôtel des ventes pour y chercher l'objet.")
        return
    end
    local name = XG.ItemName(id)
    if not name then
        -- nom pas encore chargé : on réessaie un peu plus tard
        if (tries or 0) < 5 then C_Timer.After(0.3, function() XG:SearchAH(id, (tries or 0) + 1) end) end
        return
    end
    local sb = AuctionHouseFrame and AuctionHouseFrame.SearchBar
    if not (sb and sb.SetSearchText and sb.StartSearch) then
        XG.Print("barre de recherche de l'HV introuvable.")
        return
    end
    sb:SetSearchText(name)
    local mode = AuctionHouseFrame.GetDisplayMode and AuctionHouseFrame:GetDisplayMode()
    if AuctionHouseFrameDisplayMode and mode == AuctionHouseFrameDisplayMode.Buy then
        sb:StartSearch()
    else
        XG.Print(("« %s » est prêt dans la barre de recherche de l'HV : clique dedans et appuie sur Entrée."):format(name))
    end
end
