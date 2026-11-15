-- XbiGold : métiers. Mémorise tes recettes quand tu ouvres la fenêtre d'un métier,
-- puis calcule ce qui rapporte (coût des composants vs prix de vente à l'HV).
local _, XG = ...

local floor, max, min, huge = math.floor, math.max, math.min, math.huge

-- Composants vendus par les PNJ (fils, fioles, flux, teintures, épices...) : prix d'achat
-- mémorisé chez le marchand, sinon estimé (≈ 4 × prix de revente au marchand)
XG.VENDOR_REAGENTS = {
    [3371] = true, [3372] = true, [8925] = true, [18256] = true,               -- fioles
    [2320] = true, [2321] = true, [4291] = true, [8343] = true, [14341] = true, -- fils
    [2880] = true, [3466] = true, [3857] = true, [4470] = true, [6217] = true, -- flux, charbon, bois, bâtonnet
    [4289] = true, [2324] = true, [2325] = true, [2604] = true, [2605] = true, -- sel, javelisant, teintures
    [4340] = true, [4341] = true, [4342] = true, [6260] = true, [6261] = true, [10290] = true,
    [2678] = true, [2692] = true, [3713] = true, [159] = true, [1179] = true,   -- épices, eau, lait
    [2596] = true, [2594] = true, [2593] = true, [4342] = true,                 -- alcools de cuisine
}

-- Métiers de récolte : renvoient vers l'onglet À farmer
XG.GATHER_PROF = {[182] = "herb", [186] = "ore", [393] = "leather", [356] = "other"}

local DIFF_COLOR = {[0] = "|cffff8040", [1] = "|cffffff00", [2] = "|cff40bf40", [3] = "|cff808080"}
XG.DIFF_COLOR = DIFF_COLOR

------------------------------------------------------------------------
-- Lecture des recettes (fenêtre du métier ouverte)
------------------------------------------------------------------------
local function profStore()
    XG.cdb.profs = XG.cdb.profs or {}
    return XG.cdb.profs
end

local function basicReagents(schem)
    local out = {}
    for _, slot in ipairs(schem.reagentSlotSchematics or {}) do
        local basic = slot.required
        if basic == nil then basic = (slot.reagentType == nil or slot.reagentType == 1) end
        local r = slot.reagents and slot.reagents[1]
        if basic and r and r.itemID and (slot.quantityRequired or 0) > 0 then
            out[#out + 1] = {r.itemID, slot.quantityRequired}
        end
    end
    return out
end

function XG:ScanTradeSkill()
    local T = C_TradeSkillUI
    if not T or not T.GetAllRecipeIDs or not T.IsTradeSkillReady or not T.IsTradeSkillReady() then return end
    if (T.IsDataSourceChanging and T.IsDataSourceChanging()) or (T.IsTradeSkillLinked and T.IsTradeSkillLinked())
        or (T.IsTradeSkillGuild and T.IsTradeSkillGuild()) or (T.IsNPCCrafting and T.IsNPCCrafting()) then
        return -- métier d'un autre joueur ou d'un PNJ : on ne l'enregistre pas
    end
    local base = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo() or {}
    local child = T.GetChildProfessionInfo and T.GetChildProfessionInfo() or {}
    local name = base.parentProfessionName or base.professionName or child.professionName
    if not name or name == "" then return end
    local store = profStore()
    local p = store[name] or {}
    p.name, p.t = name, time()
    p.skillLine = base.professionID or child.professionID or p.skillLine
    p.level = child.skillLevel or base.skillLevel or p.level
    p.max = child.maxSkillLevel or base.maxSkillLevel or p.max
    p.icon = base.icon or child.icon or p.icon
    p.recipes = {}
    local n = 0
    for _, rid in ipairs(T.GetAllRecipeIDs() or {}) do
        local info = T.GetRecipeInfo(rid)
        local schem = T.GetRecipeSchematic and T.GetRecipeSchematic(rid, false)
        if info and schem and not info.isDummyRecipe then
            local out = schem.outputItemID
            if not out and T.GetRecipeItemLink then
                local link = T.GetRecipeItemLink(rid)
                out = link and tonumber(link:match("item:(%d+)"))
            end
            p.recipes[rid] = {
                name = info.name, icon = info.icon, out = out,
                qmin = schem.quantityMin or 1, qmax = schem.quantityMax or schem.quantityMin or 1,
                reag = basicReagents(schem), learned = info.learned and true or false,
                diff = info.relativeDifficulty, ups = info.numSkillUps,
            }
            n = n + 1
        end
    end
    store[name] = p
    if not XG.profAnnounced or XG.profAnnounced ~= name then
        XG.profAnnounced = name
        XG.Print(("%s analysé : %d recettes. Onglet Métiers pour voir ce qui rapporte."):format(name, n))
    end
    if XG.RefreshUI then XG:RefreshUI() end
end

local pendingScan = false
local f = CreateFrame("Frame")
XG.Reg(f, "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_CLOSE")
f:SetScript("OnEvent", function(_, event)
    if not XG.cdb then return end
    if event == "TRADE_SKILL_CLOSE" then XG.profAnnounced = nil return end
    if pendingScan then return end
    pendingScan = true
    C_Timer.After(1, function()
        pendingScan = false
        pcall(XG.ScanTradeSkill, XG)
    end)
end)

------------------------------------------------------------------------
-- Calculs
------------------------------------------------------------------------
local GetCount = (C_Item and C_Item.GetItemCount) or GetItemCount

-- Prix d'un composant : le moins cher entre l'HV et le marchand (si on le connaît)
-- Renvoie prix, source ("hv" | "pnj" | "estimé")
function XG:ReagentCost(id)
    local best, src
    local v = XG:Value(id)
    if v and v > 0 then best, src = v, "hv" end
    local vend = XG.db.vendors[id]
    if vend and vend.c and (not best or vend.c < best) then best, src = vend.c, "pnj" end
    if not best and XG.VENDOR_REAGENTS[id] then
        local info = XG.ItemInfo(id)
        if info and info.sell and info.sell > 0 then best, src = info.sell * 4, "estimé" end
    end
    return best, src
end

-- Analyse d'une recette : coût, valeur de vente nette, profit, nombre faisable avec tes sacs
function XG:RecipeEval(r)
    local cost, missing = 0, false
    local craftable = huge
    for _, rg in ipairs(r.reag or {}) do
        local c = XG:ReagentCost(rg[1])
        if c then cost = cost + c * rg[2] else missing = true end
        local have = GetCount and GetCount(rg[1]) or 0
        craftable = min(craftable, floor(have / rg[2]))
    end
    if craftable == huge then craftable = 0 end
    local qty = ((r.qmin or 1) + (r.qmax or 1)) / 2
    local value, sellNet, bound
    if r.out then
        local info = XG.ItemInfo(r.out)
        bound = info and info.bind == 1
        local v = (not bound) and XG:Value(r.out) or nil
        if v and v > 0 then
            value = v
            sellNet = v * qty * (1 - XG.AH_CUT)
        elseif info and info.sell and info.sell > 0 then
            sellNet = info.sell * qty -- lié ou jamais vu à l'HV : prix du marchand
        end
    end
    local profit = sellNet and (sellNet - cost) or nil
    return {
        cost = cost, missing = missing, value = value, sellNet = sellNet, profit = profit,
        margin = (profit and cost > 0) and profit / cost or nil, craftable = craftable, qty = qty, bound = bound,
        sales = r.out and XG:SalesPerDay(r.out) or nil,
    }
end

-- Tes métiers, depuis le livre de sorts (même si la fenêtre n'a jamais été ouverte)
function XG:KnownProfessions()
    local out = {}
    if not GetProfessions then return out end
    local ok, a, b, arch, fish, cook = pcall(GetProfessions)
    if not ok then return out end
    for _, idx in ipairs({a, b, cook, fish}) do
        if idx then
            local name, icon, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
            if name then out[#out + 1] = {name = name, icon = icon, level = rank, max = maxRank, skillLine = skillLine} end
        end
    end
    return out
end
