-- XbiGold : scan complet de l'HV (C_AuctionHouse.ReplicateItems), estimation des ventes, mises à jour passives
local _, XG = ...

local floor, max, min = math.floor, math.max, math.min
local SCAN_COOLDOWN = 15 * 60
local BATCH = 1200

XG.ahOpen = false
XG.scan = {running = false, progress = 0}

local f = CreateFrame("Frame")

function XG:ScanCooldown()
    local left = SCAN_COOLDOWN - (time() - (XG.db.lastReplicate or 0))
    return max(0, left)
end

function XG:CanScan()
    return XG.ahOpen and not XG.scan.running and XG:ScanCooldown() == 0
end

-- Lance un scan complet (une fois toutes les 15 min, règle de Blizzard)
function XG:StartScan(silent)
    if not XG.ahOpen then
        if not silent then XG.Print("ouvre l'hôtel des ventes pour lancer un scan.") end
        return
    end
    if XG.scan.running then return end
    local left = XG:ScanCooldown()
    if left > 0 then
        if not silent then XG.Print(("prochain scan complet possible dans %s."):format(XG.Duration(left))) end
        return
    end
    C_AuctionHouse.ReplicateItems() -- le hook ci-dessous prend la suite
end

-- Les scans lancés par Auctionator / TSM servent aussi à XbiGold
if C_AuctionHouse and C_AuctionHouse.ReplicateItems then
    hooksecurefunc(C_AuctionHouse, "ReplicateItems", function()
        XG.db.lastReplicate = time()
        XG.scan.running = true
        XG.scan.progress = 0.05
        XG.scan.waiting = true
        f:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
        if XG.OnScanProgress then XG:OnScanProgress() end
    end)
end

------------------------------------------------------------------------
-- Instantané des vendeurs : sert à estimer les ventes entre deux scans
------------------------------------------------------------------------
local function packSnap(owners)
    local parts = {}
    for o, v in pairs(owners) do
        parts[#parts + 1] = o .. "," .. v[1] .. "," .. v[2] .. "," .. v[3] .. "," .. v[4]
    end
    return table.concat(parts, ";")
end

local function unpackSnap(s)
    local t = {}
    if not s then return t end
    for o, q, e1, e2, e3 in s:gmatch("([^,;]+),(%d+),(%d+),(%d+),(%d+)") do
        t[o] = {tonumber(q), tonumber(e1), tonumber(e2), tonumber(e3)}
    end
    return t
end

-- Annonces disparues avant leur expiration = vendues (ou annulées) : estimation des ventes par jour
local function estimateSales(key, prevStr, curOwners, dt)
    if not prevStr or dt < 300 or dt > 12 * 3600 then return nil end
    local prev = unpackSnap(prevStr)
    local sold = 0
    for o, pv in pairs(prev) do
        local cur = curOwners and curOwners[o]
        local cq = cur and cur[1] or 0
        local drop = pv[1] - cq
        if drop > 0 then
            -- ce qui pouvait expirer pendant l'intervalle ne compte pas comme vendu
            local expiring = dt <= 1800 and pv[2] or (dt <= 7200 and pv[3] or pv[4])
            sold = sold + max(0, drop - expiring)
        end
    end
    return sold * 86400 / dt
end

------------------------------------------------------------------------
-- Traitement du scan
------------------------------------------------------------------------
local acc, owners, index, total, scanTime

local function finish()
    local now = scanTime
    local M = XG.M
    local S = XG.S
    local prevSnap, prevTime = M.snap or {}, M.snapTime or 0
    local dt = now - prevTime
    local newSnap = {}
    local deals = {}
    local seen = {}
    local count = 0

    for key, list in pairs(acc) do
        count = count + 1
        seen[key] = true
        table.sort(list, function(a, b) return a[1] < b[1] end)
        local qty, n = 0, #list
        for i = 1, n do qty = qty + list[i][2] end
        local mkt = XG.ComputeMarket(list)
        local id = XG.IDFromKey(key)

        -- Ventes estimées
        local own = owners[key]
        local rate = estimateSales(key, prevSnap[key], own, dt)
        local it = M.items[key]
        if rate and it then
            it.sr = it.sr and floor((it.sr * 0.7 + rate * 0.3) * 10 + 0.5) / 10 or floor(rate * 10 + 0.5) / 10
            it.srn = (it.srn or 0) + 1
        end
        if own then newSnap[key] = packSnap(own) end

        -- Bonne affaire ? (comparée aux jours précédents, avant d'enregistrer aujourd'hui)
        local ref, refDays = XG:PastValue(key)
        if not ref and it and it.d and it.d[XG.Today()] then ref, refDays = it.d[XG.Today()], 0 end
        local info = id and XG.ItemInfo(id)
        local deal = XG.FindDeal(list, {
            ref = ref, refDays = refDays, sell = info and info.sell or 0,
            sales = it and it.sr, minProfit = S.minProfit, minMargin = S.minMargin,
        })
        if deal then
            deal.key, deal.id, deal.t, deal.ref, deal.total = key, id, now, ref, qty
            deals[#deals + 1] = deal
        end

        XG:RecordScan(key, mkt or list[1][1], list[1][1], qty, n, now)
    end

    -- Objets entièrement vendus depuis le dernier scan
    for key, prevStr in pairs(prevSnap) do
        if not acc[key] then
            local it = M.items[key]
            local rate = it and estimateSales(key, prevStr, nil, dt)
            if rate then
                it.sr = it.sr and floor((it.sr * 0.7 + rate * 0.3) * 10 + 0.5) / 10 or floor(rate * 10 + 0.5) / 10
                it.srn = (it.srn or 0) + 1
            end
        end
    end

    -- Objets qui ont disparu de l'HV : plus aucun vendeur
    for key, it in pairs(M.items) do
        if not seen[key] and (it.q or 0) > 0 then it.q, it.n = 0, 0 end
    end

    table.sort(deals, function(a, b) return a.profit > b.profit end)
    while #deals > 300 do table.remove(deals) end
    M.deals = deals
    M.snap, M.snapTime = newSnap, now
    M.lastScan, M.scans = now, (M.scans or 0) + 1
    M.lastCount = count

    acc, owners = nil, nil
    XG.scan.running, XG.scan.progress = false, 1

    local sum = 0
    for i = 1, #deals do sum = sum + deals[i].profit end
    XG.Print(("scan terminé : %s objets, %s%d bonne(s) affaire(s)|r (%s de profit possible)."):format(
        XG.Num(count), XG.C.green, #deals, XG.Money(sum)))
    if S.dealAlert and deals[1] and deals[1].profit >= S.minProfit * 10 then
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.MONEY_FRAME_OPEN or 891)
    end
    if XG.Sync_AfterScan then pcall(XG.Sync_AfterScan, XG, now) end
    if XG.OnScanDone then XG:OnScanDone() end
    if XG.neutral and not XG.ahOpen then XG:SelectMarket(false) end
end

local function processBatch()
    if not XG.scan.running or not acc then return end
    if not XG.ahOpen then
        XG.scan.running = false
        acc, owners = nil, nil
        XG.Print("scan interrompu : l'hôtel des ventes a été fermé.")
        if XG.neutral then XG:SelectMarket(false) end
        if XG.OnScanProgress then XG:OnScanProgress() end
        return
    end
    local last = min(index + BATCH, total) - 1
    local GetInfo, GetLink, GetLeft = C_AuctionHouse.GetReplicateItemInfo, C_AuctionHouse.GetReplicateItemLink,
        C_AuctionHouse.GetReplicateItemTimeLeft
    for i = index, last do
        local _, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID, hasAll = GetInfo(i)
        if itemID and buyout and buyout > 0 and count and count > 0 then
            local key
            if hasAll and XG.IsGear(itemID) then key = XG.KeyFromLink(GetLink(i)) end
            key = key or tostring(itemID)
            local list = acc[key]
            if not list then list = {}; acc[key] = list end
            list[#list + 1] = {floor(buyout / count), count}
            -- vendeur et temps restant (Court = 0, Moyen = 1, Long = 2, Très long = 3)
            local o = owner and owner ~= "" and owner or "?"
            local tl = GetLeft and GetLeft(i) or 3
            local ok = owners[key]
            if not ok then ok = {}; owners[key] = ok end
            local v = ok[o]
            if not v then v = {0, 0, 0, 0}; ok[o] = v end
            v[1] = v[1] + count
            if tl == 0 then v[2] = v[2] + count end
            if tl <= 1 then v[3] = v[3] + count end
            if tl <= 2 then v[4] = v[4] + count end
        end
    end
    index = last + 1
    XG.scan.progress = 0.1 + 0.9 * (index / max(1, total))
    if XG.OnScanProgress then XG:OnScanProgress() end
    if index >= total then
        finish()
    else
        C_Timer.After(0, processBatch)
    end
end

local function startProcessing()
    acc, owners = {}, {}
    index, total = 0, C_AuctionHouse.GetNumReplicateItems() or 0
    scanTime = time()
    XG.scan.waiting = false
    if total == 0 then
        XG.scan.running = false
        XG.Print("le scan n'a rien renvoyé (HV vide ou serveur occupé). Réessaie dans 15 min.")
        if XG.OnScanProgress then XG:OnScanProgress() end
        return
    end
    -- petit délai : laisse le client charger les infos des annonces
    C_Timer.After(0.5, processBatch)
end

------------------------------------------------------------------------
-- Mises à jour passives : chaque recherche faite à l'HV (par toi ou un addon) rafraîchit les prix
------------------------------------------------------------------------
local function recordBook(key, entries)
    if #entries == 0 then return end
    table.sort(entries, function(a, b) return a[1] < b[1] end)
    local qty = 0
    for i = 1, #entries do qty = qty + entries[i][2] end
    XG:RecordScan(key, XG.ComputeMarket(entries) or entries[1][1], entries[1][1], qty, #entries, time())
end

local function onCommodityResults(itemID)
    if not itemID or (C_AuctionHouse.HasFullCommoditySearchResults and not C_AuctionHouse.HasFullCommoditySearchResults(itemID)) then return end
    local entries = {}
    for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) do
        local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if r and r.unitPrice and r.unitPrice > 0 then entries[#entries + 1] = {r.unitPrice, r.quantity or 1} end
    end
    recordBook(tostring(itemID), entries)
end

local function onItemResults(itemKey)
    if not itemKey or not itemKey.itemID then return end
    if C_AuctionHouse.HasFullItemSearchResults and not C_AuctionHouse.HasFullItemSearchResults(itemKey) then return end
    local byKey = {}
    for i = 1, C_AuctionHouse.GetNumItemSearchResults(itemKey) do
        local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if r and r.buyoutAmount and r.buyoutAmount > 0 then
            local key = (r.itemLink and XG.IsGear(itemKey.itemID) and XG.KeyFromLink(r.itemLink)) or tostring(itemKey.itemID)
            byKey[key] = byKey[key] or {}
            table.insert(byKey[key], {r.buyoutAmount, r.quantity or 1})
        end
    end
    for key, entries in pairs(byKey) do recordBook(key, entries) end
end

XG.Reg(f, "AUCTION_HOUSE_SHOW")
XG.Reg(f, "AUCTION_HOUSE_CLOSED")
XG.Reg(f, "COMMODITY_SEARCH_RESULTS_UPDATED")
XG.Reg(f, "ITEM_SEARCH_RESULTS_UPDATED")
f:SetScript("OnEvent", function(self, event, ...)
    if not XG.M then return end
    if event == "AUCTION_HOUSE_SHOW" then
        XG.ahOpen = true
        if XG:AtNeutralAH() then
            XG:SelectMarket(true)
            XG.Print("HV neutre : prix séparés et commission de 15 %.")
        end
        if XG.OnAHShow then XG:OnAHShow() end
        if XG.S.autoScan then
            C_Timer.After(2, function() if XG:CanScan() then XG:StartScan(true) end end)
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        XG.ahOpen = false
        if XG.neutral and not XG.scan.running then XG:SelectMarket(false) end
        if XG.OnAHClose then XG:OnAHClose() end
        if XG.scan.waiting then
            XG.scan.running, XG.scan.waiting = false, false
            self:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
            XG.Print("scan annulé : l'hôtel des ventes a été fermé avant la réponse du serveur.")
        end
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        self:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
        if XG.scan.waiting then startProcessing() end
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local ok = pcall(onCommodityResults, ...)
        if XG.Buyer_OnCommodityResults then XG:Buyer_OnCommodityResults(...) end
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        pcall(onItemResults, ...)
        if XG.Buyer_OnItemResults then XG:Buyer_OnItemResults(...) end
    end
end)
