-- XbiGold : petits graphiques (courbes + barres, survol à la souris)
local _, XG = ...

local UI, R = XG.UI, XG.RGB
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

-- c:Draw(opts)
--   opts.xs        positions horizontales (0 à 1), une par point
--   opts.series    {{values = {...}, color = {r, g, b}, thick = 2}, ...} (valeur nil = trou)
--   opts.bars      {values = {...}, color = {r, g, b, a}, colors = {...par barre}, height = 0.35, width = 0.8}
--   opts.yFmt      fonction pour les étiquettes de l'axe vertical
--   opts.xLabels   {{x = 0..1, text = "..."}, ...}
--   opts.hover     fonction(i) -> lignes de l'infobulle pour le point i
--   opts.barsOnly  pas d'axe de prix : les barres prennent toute la hauteur
function UI.Chart(parent, w, h)
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(w, h)
    UI.Fill(c, R.panel2)
    local LEFT, BOTTOM, TOP, RIGHT = 58, 18, 10, 10
    local pw, ph = w - LEFT - RIGHT, h - BOTTOM - TOP
    local plot = CreateFrame("Frame", nil, c)
    plot:SetPoint("BOTTOMLEFT", LEFT, BOTTOM)
    plot:SetSize(pw, ph)
    c.plot, c.pw, c.ph = plot, pw, ph

    local pools = {line = {}, dot = {}, bar = {}, grid = {}, ylab = {}, xlab = {}}
    local used = {}
    local function get(kind, make)
        used[kind] = (used[kind] or 0) + 1
        local o = pools[kind][used[kind]]
        if not o then
            o = make()
            pools[kind][used[kind]] = o
        end
        o:Show()
        return o
    end
    local function reset()
        for kind, list in pairs(pools) do for _, o in ipairs(list) do o:Hide() end end
        used = {}
    end

    local marker = UI.Tex(plot, "OVERLAY", 1, 1, 1, 0.25)
    marker:SetWidth(1)
    marker:Hide()

    c.empty = UI.Text(c, 12, R.muted, "CENTER")
    c.empty:SetPoint("CENTER", plot, "CENTER")
    c.empty:SetWidth(pw - 20)
    c.empty:SetWordWrap(true)

    local function seg(x1, y1, x2, y2, color, thick)
        if plot.CreateLine then
            local l = get("line", function() return plot:CreateLine(nil, "ARTWORK") end)
            l:SetThickness(thick or 2)
            l:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
            l:SetStartPoint("BOTTOMLEFT", plot, x1, y1)
            l:SetEndPoint("BOTTOMLEFT", plot, x2, y2)
        end
    end
    local function dot(x, y, color, size)
        local d = get("dot", function() return plot:CreateTexture(nil, "OVERLAY") end)
        d:SetColorTexture(color[1], color[2], color[3], 1)
        d:SetSize(size or 4, size or 4)
        d:ClearAllPoints()
        d:SetPoint("CENTER", plot, "BOTTOMLEFT", x, y)
    end

    function c:Draw(o)
        reset()
        self.opts = o
        local xs = o.xs or {}
        local n = #xs
        c.empty:SetShown(o.emptyText ~= nil)
        c.empty:SetText(o.emptyText or "")
        if n == 0 then return end

        -- échelle des prix
        local lo, hi = math.huge, -math.huge
        for _, s in ipairs(o.series or {}) do
            for i = 1, n do local v = s.values[i] if v then lo, hi = min(lo, v), max(hi, v) end end
        end
        local hasY = lo <= hi
        if hasY then
            if lo == hi then lo, hi = lo * 0.9, hi * 1.1 + 1 end
            local pad = (hi - lo) * 0.12
            lo, hi = max(0, lo - pad), hi + pad
        end
        local function Y(v) return (v - lo) / (hi - lo) * ph end

        -- grille + étiquettes
        if hasY and not o.barsOnly then
            for k = 0, 3 do
                local v = lo + (hi - lo) * k / 3
                local g = get("grid", function() return UI.Tex(plot, "BACKGROUND", 1, 1, 1, 0.05) end)
                g:ClearAllPoints()
                g:SetPoint("BOTTOMLEFT", plot, "BOTTOMLEFT", 0, Y(v))
                g:SetSize(pw, 1)
                local t = get("ylab", function() return UI.Text(c, 9, R.muted, "RIGHT") end)
                t:ClearAllPoints()
                t:SetPoint("RIGHT", plot, "BOTTOMLEFT", -6, Y(v))
                t:SetText((o.yFmt or tostring)(v))
            end
        end
        for _, xl in ipairs(o.xLabels or {}) do
            local t = get("xlab", function() return UI.Text(c, 9, R.muted, "CENTER") end)
            t:ClearAllPoints()
            t:SetPoint("TOP", plot, "BOTTOMLEFT", xl.x * pw, -4)
            t:SetText(xl.text)
        end

        -- barres
        local b = o.bars
        if b and b.values then
            local bmax = 0
            for i = 1, n do if b.values[i] then bmax = max(bmax, b.values[i]) end end
            local bh = (o.barsOnly and 1 or (b.height or 0.35)) * ph
            local bw = max(2, pw / max(n, 1) * (b.width or 0.7))
            if bmax > 0 then
                for i = 1, n do
                    local v = b.values[i]
                    if v and v > 0 then
                        local col = (b.colors and b.colors[i]) or b.color or {1, 1, 1, 0.15}
                        local t = get("bar", function() return plot:CreateTexture(nil, "BORDER") end)
                        t:SetColorTexture(col[1], col[2], col[3], col[4] or 1)
                        t:ClearAllPoints()
                        t:SetPoint("BOTTOM", plot, "BOTTOMLEFT", xs[i] * pw, 0)
                        t:SetSize(bw, max(1, v / bmax * bh))
                    end
                end
            end
        end

        -- courbes
        if hasY then
            for _, s in ipairs(o.series or {}) do
                local px, py
                for i = 1, n do
                    local v = s.values[i]
                    if v then
                        local x, y = xs[i] * pw, Y(v)
                        if px then seg(px, py, x, y, s.color, s.thick) end
                        if s.dots ~= false then dot(x, y, s.color, s.dotSize) end
                        px, py = x, y
                    end
                end
            end
        end
    end

    -- survol : point le plus proche
    plot:EnableMouse(true)
    plot:SetScript("OnEnter", function(self)
        self:SetScript("OnUpdate", function()
            local o = c.opts
            if not o or not o.xs or #o.xs == 0 or not o.hover then return end
            local cx = GetCursorPosition() / self:GetEffectiveScale() - (self:GetLeft() or 0)
            local best, bd = 1, math.huge
            for i, x in ipairs(o.xs) do
                local d = abs(x * pw - cx)
                if d < bd then best, bd = i, d end
            end
            if c.hoverIndex ~= best then
                c.hoverIndex = best
                marker:ClearAllPoints()
                marker:SetPoint("BOTTOM", plot, "BOTTOMLEFT", o.xs[best] * pw, 0)
                marker:SetHeight(ph)
                marker:Show()
                local lines = o.hover(best)
                GameTooltip:SetOwner(plot, "ANCHOR_CURSOR")
                for k, l in ipairs(lines or {}) do
                    if k == 1 then GameTooltip:AddLine(l, 1, 1, 1) else GameTooltip:AddLine(l, 0.85, 0.88, 0.92) end
                end
                GameTooltip:Show()
            end
        end)
    end)
    plot:SetScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil)
        c.hoverIndex = nil
        marker:Hide()
        GameTooltip:Hide()
    end)
    return c
end
