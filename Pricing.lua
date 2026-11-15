-- XbiGold : calcul de la valeur marché, détection des bonnes affaires, conseils de vente
local _, XG = ...

local floor, ceil, max, min, sqrt, abs = math.floor, math.ceil, math.max, math.min, math.sqrt, math.abs

-- listings : liste triée par prix croissant de {prix unitaire, quantité}
-- Valeur marché : moyenne pondérée des 15 à 30 % d'unités les moins chères, sans les valeurs aberrantes
function XG.ComputeMarket(listings)
    local n = #listings
    if n == 0 then return nil end
    local total = 0
    for i = 1, n do total = total + listings[i][2] end
    local lo, hi = total * 0.15, total * 0.30
    local cum, sel = 0, {}
    for i = 1, n do
        local p, q = listings[i][1], listings[i][2]
        if cum >= lo then
            local prev = listings[i - 1] and listings[i - 1][1] or p
            if cum >= hi or p > prev * 1.2 then break end
        end
        local take = q
        if cum + take > hi and cum >= lo then take = max(1, floor(hi - cum)) end
        sel[#sel + 1] = {p, take}
        cum = cum + take
    end
    local function wmean(t)
        local s, w = 0, 0
        for i = 1, #t do s = s + t[i][1] * t[i][2]; w = w + t[i][2] end
        return w > 0 and s / w or nil
    end
    local m = wmean(sel)
    if not m then return listings[1][1] end
    if #sel > 2 then
        local var, w = 0, 0
        for i = 1, #sel do var = var + sel[i][2] * (sel[i][1] - m) ^ 2; w = w + sel[i][2] end
        local sd = sqrt(var / w)
        if sd > 0 then
            local kept = {}
            for i = 1, #sel do if abs(sel[i][1] - m) <= 1.5 * sd then kept[#kept + 1] = sel[i] end end
            local m2 = wmean(kept)
            if m2 then m = m2 end
        end
    end
    return floor(m + 0.5)
end

-- Cherche la meilleure affaire sur un objet à partir du carnet d'annonces trié.
-- opts : ref (valeur de référence), refDays, sell (prix marchand), sales (ventes/jour),
--        minProfit, minMargin, cut
-- Renvoie nil ou {type, qty, cost, maxUnit, resale, profit, margin, conf, low}
function XG.FindDeal(listings, opts)
    local n = #listings
    if n == 0 then return nil end
    local cut = opts.cut or XG.AH_CUT
    local minProfit, minMargin = opts.minProfit or 5000, opts.minMargin or 0.25
    local ref, refDays = opts.ref, opts.refDays or 0
    local total = 0
    for i = 1, n do total = total + listings[i][2] end

    -- 1) Moins cher que le prix de vente au marchand : sans risque
    local sell = opts.sell or 0
    if sell > 0 then
        local qty, cost, profit, maxUnit = 0, 0, 0, 0
        for i = 1, n do
            local p, q = listings[i][1], listings[i][2]
            if p < sell * 0.97 then
                qty, cost = qty + q, cost + p * q
                profit = profit + (sell - p) * q
                maxUnit = p
            else
                break
            end
        end
        if qty > 0 and profit >= max(500, minProfit * 0.2) then
            return {type = "vendor", qty = qty, cost = cost, maxUnit = maxUnit, resale = sell,
                    profit = floor(profit), margin = cost > 0 and profit / cost or 1, conf = 3, low = listings[1][1]}
        end
    end

    -- 2) Revente à l'HV : acheter les annonces trop basses et revendre au niveau suivant
    local sales = opts.sales
    local capQty = sales and sales > 0 and max(1, ceil(sales * 3)) or nil
    local best
    local cumQ, cumCost = 0, 0
    for j = 1, min(n, 40) do
        local p, q = listings[j][1], listings[j][2]
        if cumQ + q > total * 0.5 and j > 1 then break end
        local takeQ = q
        if capQty and cumQ + takeQ > capQty then takeQ = capQty - cumQ end
        if takeQ <= 0 then break end
        cumQ, cumCost = cumQ + takeQ, cumCost + p * takeQ

        -- Prix de revente : l'annonce suivante, plafonnée par la référence
        local nextL = listings[j + 1]
        local R
        if nextL then
            R = nextL[1]
            if ref and refDays >= 1 then
                R = min(R, floor(ref * 1.15))
            else
                -- pas d'historique : le niveau suivant doit être confirmé par une 2e annonce proche
                local n2 = listings[j + 2]
                if not ref and not (n2 and n2[1] <= R * 1.25) then R = nil end
                if R and ref then R = min(R, floor(ref * 1.15)) end
            end
        elseif ref and refDays >= 2 then
            R = ref
        end
        -- Prudence : si on achèterait plus que ce qui reste en vente au-dessus, c'est peut-être le vrai prix
        -- (sauf avec un historique solide et des ventes connues)
        local strong = ref and refDays >= 3 and sales and sales > 0
        if R and not strong and (total - cumQ) < cumQ then R = nil end

        if R and R > 0 then
            local net = R * (1 - cut)
            if p <= net / (1 + minMargin) then
                local profit = cumQ * net - cumCost
                if not best or profit > best.profit then
                    local conf = 1
                    if ref and refDays >= 3 and R <= ref * 1.1 and sales and sales > 0 then conf = 3
                    elseif ref and refDays >= 1 and R <= ref * 1.3 then conf = 2 end
                    best = {type = "flip", qty = cumQ, cost = cumCost, maxUnit = p, resale = R,
                            profit = floor(profit), margin = profit / cumCost, conf = conf, low = listings[1][1]}
                end
            else
                break -- les annonces suivantes sont encore plus chères
            end
        end
        if capQty and cumQ >= capQty then break end
    end
    if best and best.profit >= minProfit then return best end
    return nil
end

-- Conseil de vente pour un objet de tes sacs
-- Renvoie where ("hv" | "marchand" | "garder"), unitAH, unitVendor, reason
function XG:SellAdvice(key, id, count, bound)
    local info = XG.ItemInfo(id)
    local sell = info and info.sell or 0
    count = count or 1
    if bound then
        if sell > 0 then return "marchand", nil, sell, "lié" end
        return "garder", nil, 0, "lié, sans valeur marchande"
    end
    local v, src = XG:Value(key)
    if not v or v <= 0 then
        if sell > 0 then return "marchand", nil, sell, "jamais vu à l'HV" end
        return "garder", nil, 0, "pas de prix connu"
    end
    local net = v * (1 - XG.AH_CUT)
    if net < sell * 1.15 then return "marchand", v, sell, "le marchand paie presque autant" end
    -- petits objets : le dépôt minimum (1 pa par annonce au lancement) mange le bénéfice
    if net * count < 300 then return "marchand", v, sell, "trop peu de valeur pour l'HV" end
    local it = XG:Item(key)
    if it and it.q == 0 and (it.t or 0) > time() - 6 * 3600 then
        return "hv", v, sell, "personne n'en vend : fixe ton prix !"
    end
    return "hv", v, sell, nil
end

-- Prix conseillé pour poster : le plus bas actuel, sauf s'il est cassé (on reste sur la valeur marché)
function XG:SuggestedPrice(key)
    local it = XG:Item(key)
    local v = XG:Value(key)
    if not it or not it.l or it.l <= 0 then return v end
    if v and it.l < v * 0.8 then return v, "le prix le plus bas est cassé, attends ou poste à la valeur marché" end
    return it.l
end
