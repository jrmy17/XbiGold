-- XbiGold : outils communs (argent, nombres, objets, couleurs)
local _, XG = ...
XbiGold = XG -- accès depuis /dump et les autres addons

local floor, fmt, abs = math.floor, string.format, math.abs

XG.NAME = "|cff4fc3f7Xbi|r|cffffd100Gold|r"
XG.AH_CUT = 0.05 -- part prise par l'HV de faction sur une vente

XG.C = {
    gold = "|cffffd100", silver = "|cffc7c7cf", copper = "|cffeda55f",
    green = "|cff3fe35b", red = "|cffff5a4f", yellow = "|cffffd24a", grey = "|cff8a93a0",
    white = "|cffffffff", blue = "|cff4fc3f7", soft = "|cffc8d3dc", orange = "|cffff9f43",
}
XG.RGB = {
    bg = {0.055, 0.063, 0.078}, panel = {0.082, 0.094, 0.114}, panel2 = {0.106, 0.122, 0.149},
    line = {1, 1, 1, 0.06}, accent = {1, 0.82, 0}, blue = {0.31, 0.76, 0.97},
    green = {0.25, 0.89, 0.36}, red = {1, 0.35, 0.31}, text = {0.92, 0.94, 0.96}, muted = {0.54, 0.58, 0.63},
}

-- Enregistre un événement sans erreur s'il n'existe pas dans ce client
function XG.Reg(frame, ...)
    for i = 1, select("#", ...) do
        pcall(frame.RegisterEvent, frame, (select(i, ...)))
    end
end

function XG.Print(...)
    print(XG.NAME .. " :", ...)
end

-- Nombre à la française : 1 234 / 1,5
function XG.Num(v, decimals)
    if not v then return "-" end
    decimals = decimals or 0
    local neg = v < 0
    v = abs(v)
    local s = fmt("%." .. decimals .. "f", v)
    local int, frac = s:match("^(%d+)%.?(%d*)$")
    int = int or s
    int = int:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    if frac and frac ~= "" then
        frac = frac:gsub("0+$", "")
        if frac ~= "" then int = int .. "," .. frac end
    end
    return (neg and "-" or "") .. int
end

function XG.Pct(v)
    if not v then return "-" end
    return XG.Num(v * 100, 0) .. " %"
end

-- Argent compact : "12 po 34 pa", "1 234 po", "45 pa", "8 pc"
function XG.Money(c, plain)
    if not c then return XG.C.grey .. "-|r" end
    c = floor(c + 0.5)
    local neg = c < 0
    c = abs(c)
    local g, s, cu = floor(c / 10000), floor((c % 10000) / 100), c % 100
    local G = plain and " po" or (XG.C.gold .. "po|r")
    local S = plain and " pa" or (XG.C.silver .. "pa|r")
    local P = plain and " pc" or (XG.C.copper .. "pc|r")
    local sep = plain and " " or " "
    local out
    if g >= 100 then
        out = XG.Num(g) .. sep .. G
    elseif g > 0 then
        out = g .. sep .. G .. (s > 0 and (" " .. s .. sep .. S) or "")
    elseif s > 0 then
        out = s .. sep .. S .. ((s < 10 and cu > 0) and (" " .. cu .. sep .. P) or "")
    else
        out = cu .. sep .. P
    end
    if plain then out = out:gsub("  ", " ") end
    return (neg and "-" or "") .. out
end

function XG.Ago(t)
    if not t or t == 0 then return "jamais" end
    local d = time() - t
    if d < 60 then return "à l'instant" end
    if d < 3600 then return "il y a " .. floor(d / 60) .. " min" end
    if d < 86400 then return "il y a " .. floor(d / 3600) .. " h" end
    return "il y a " .. floor(d / 86400) .. " j"
end

function XG.Duration(sec)
    sec = floor(sec or 0)
    local h, m, s = floor(sec / 3600), floor((sec % 3600) / 60), sec % 60
    if h > 0 then return fmt("%d h %02d", h, m) end
    return fmt("%d:%02d", m, s)
end

-- Jour courant (index de jour, pour l'historique)
function XG.Today()
    return floor(time() / 86400)
end

------------------------------------------------------------------------
-- Objets
------------------------------------------------------------------------
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local RequestLoad = C_Item and C_Item.RequestLoadItemDataByID

local infoCache = {}
local pending, pendingCount = {}, 0

-- name, link, quality, ilvl, reqLevel, maxStack, sellPrice, icon, classID, subclassID, bindType
function XG.ItemInfo(id)
    if not id then return nil end
    local c = infoCache[id]
    if c then return c end
    local name, link, quality, ilvl, req, _, _, stack, _, icon, sell, classID, subID, bind = GetItemInfo(id)
    if name then
        c = {name = name, link = link, quality = quality or 1, ilvl = ilvl or 0, req = req or 0, stack = stack or 1,
             sell = sell or 0, icon = icon, classID = classID, subID = subID, bind = bind or 0}
        infoCache[id] = c
        return c
    end
    if RequestLoad and not pending[id] then
        pending[id] = true
        pendingCount = pendingCount + 1
        pcall(RequestLoad, id)
    end
    return nil
end

function XG.ItemName(id)
    local i = XG.ItemInfo(id)
    if i then return i.name end
    return nil
end

function XG.ItemIcon(id)
    local i = XG.ItemInfo(id)
    if i and i.icon then return i.icon end
    return (GetItemIcon and GetItemIcon(id)) or 134400
end

function XG.ItemClass(id)
    if not GetItemInfoInstant then return nil end
    local _, _, _, equipLoc, _, classID, subID = GetItemInfoInstant(id)
    return classID, subID, equipLoc
end

-- Arme (2) ou armure (4) : la valeur dépend du suffixe ("du singe", etc.)
function XG.IsGear(id)
    local classID = XG.ItemClass(id)
    return classID == 2 or classID == 4
end

function XG.QualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
    if c and c.hex then return c.hex end
    return "|cffffffff"
end

-- Clé d'un objet à partir d'un lien : "id" ou "id:suffixe" pour l'équipement à suffixe aléatoire
function XG.KeyFromLink(link)
    if not link then return nil end
    local id, _, _, _, _, _, suffix = link:match("item:(%d+):?(%-?%d*):?(%-?%d*):?(%-?%d*):?(%-?%d*):?(%-?%d*):?(%-?%d*)")
    if not id then return nil end
    if suffix and suffix ~= "" and suffix ~= "0" then return id .. ":" .. suffix, tonumber(id) end
    return id, tonumber(id)
end

function XG.IDFromKey(key)
    return tonumber((tostring(key):match("^(%d+)")))
end

-- Rafraîchit l'interface quand des infos d'objets arrivent (regroupé)
local refreshQueued = false
local itemFrame = CreateFrame("Frame")
itemFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemFrame:SetScript("OnEvent", function(_, _, id)
    if id and pending[id] then
        pending[id] = nil
        pendingCount = pendingCount - 1
    end
    if not refreshQueued then
        refreshQueued = true
        C_Timer.After(0.4, function()
            refreshQueued = false
            if XG.OnItemInfo then XG:OnItemInfo() end
        end)
    end
end)

------------------------------------------------------------------------
-- Petits outils
------------------------------------------------------------------------
function XG.Median(t)
    local n = #t
    if n == 0 then return nil end
    local c = {}
    for i = 1, n do c[i] = t[i] end
    table.sort(c)
    if n % 2 == 1 then return c[(n + 1) / 2] end
    return (c[n / 2] + c[n / 2 + 1]) / 2
end

function XG.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function XG.PlayerFaction()
    local f = UnitFactionGroup("player")
    return f == "Horde" and 2 or 1
end

function XG.ZoneName(uiMapID)
    if not uiMapID or not C_Map or not C_Map.GetMapInfo then return "" end
    local info = C_Map.GetMapInfo(uiMapID)
    return info and info.name or ""
end
