-- XbiGold : petits composants d'interface (style plat et sombre)
local _, XG = ...

local UI = {}
XG.UI = UI
local R = XG.RGB
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

function UI.Tex(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

function UI.Fill(frame, rgb, a)
    local t = UI.Tex(frame, "BACKGROUND", rgb[1], rgb[2], rgb[3], a or rgb[4] or 1)
    t:SetAllPoints()
    frame.bg = t
    return t
end

-- Bordure de 1 pixel
function UI.Border(frame, r, g, b, a)
    r, g, b, a = r or 1, g or 1, b or 1, a or 0.08
    local function edge(p1, p2, w, h)
        local t = UI.Tex(frame, "BORDER", r, g, b, a)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        return t
    end
    frame.borders = {edge("TOPLEFT", "TOPRIGHT", nil, 1), edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1),
                     edge("TOPLEFT", "BOTTOMLEFT", 1, nil), edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)}
end

function UI.Text(parent, size, rgb, justify, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 12, flags or "")
    rgb = rgb or R.text
    fs:SetTextColor(rgb[1], rgb[2], rgb[3], rgb[4] or 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- Bouton : style "primary" (or), "ghost" (discret), "success" (vert)
local STYLES = {
    primary = {bg = {1, 0.78, 0.1}, hover = {1, 0.86, 0.3}, text = {0.08, 0.07, 0.04}},
    ghost = {bg = {0.14, 0.16, 0.2}, hover = {0.19, 0.22, 0.27}, text = {0.9, 0.92, 0.95}},
    success = {bg = {0.18, 0.62, 0.3}, hover = {0.22, 0.72, 0.36}, text = {1, 1, 1}},
    danger = {bg = {0.55, 0.18, 0.16}, hover = {0.66, 0.22, 0.2}, text = {1, 1, 1}},
}
function UI.Button(parent, text, w, h, style, onClick)
    local st = STYLES[style or "ghost"]
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 100, h or 24)
    b.bg = UI.Tex(b, "BACKGROUND", st.bg[1], st.bg[2], st.bg[3], 1)
    b.bg:SetAllPoints()
    b.label = UI.Text(b, 12, st.text, "CENTER")
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(text)
    b.style = st
    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then self.bg:SetColorTexture(st.hover[1], st.hover[2], st.hover[3], 1) end
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.tip, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(st.bg[1], st.bg[2], st.bg[3], self:IsEnabled() and 1 or 0.35)
        if self.tip then GameTooltip:Hide() end
    end)
    b:SetScript("OnEnable", function(self)
        self.bg:SetColorTexture(st.bg[1], st.bg[2], st.bg[3], 1)
        self.label:SetAlpha(1)
    end)
    b:SetScript("OnDisable", function(self)
        self.bg:SetColorTexture(st.bg[1], st.bg[2], st.bg[3], 0.35)
        self.label:SetAlpha(0.45)
    end)
    if onClick then b:SetScript("OnClick", onClick) end
    function b:SetText(t) self.label:SetText(t) end
    return b
end

-- Case à cocher moderne (interrupteur)
function UI.Toggle(parent, label, get, set, tip)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(320, 22)
    local track = CreateFrame("Frame", nil, f)
    track:SetSize(30, 16)
    track:SetPoint("LEFT")
    track.bg = UI.Tex(track, "BACKGROUND", 0.2, 0.22, 0.27, 1)
    track.bg:SetAllPoints()
    local knob = UI.Tex(track, "ARTWORK", 1, 1, 1, 1)
    knob:SetSize(12, 12)
    local txt = UI.Text(f, 12, R.text)
    txt:SetPoint("LEFT", track, "RIGHT", 10, 0)
    txt:SetText(label)
    function f:Refresh()
        local on = get()
        knob:ClearAllPoints()
        if on then
            knob:SetPoint("RIGHT", track, "RIGHT", -2, 0)
            track.bg:SetColorTexture(1, 0.78, 0.1, 1)
        else
            knob:SetPoint("LEFT", track, "LEFT", 2, 0)
            track.bg:SetColorTexture(0.2, 0.22, 0.27, 1)
        end
    end
    f:SetScript("OnClick", function(self)
        set(not get())
        self:Refresh()
    end)
    if tip then
        f:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label, 1, 1, 1)
            GameTooltip:AddLine(tip, 0.8, 0.83, 0.86, true)
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", GameTooltip_Hide)
    end
    f:Refresh()
    return f
end

-- Sélecteur de valeur : [-] valeur [+]
function UI.Stepper(parent, label, values, fmtFn, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(380, 24)
    local txt = UI.Text(f, 12, R.text)
    txt:SetPoint("LEFT")
    txt:SetText(label)
    local val = UI.Text(f, 12, {1, 0.82, 0}, "CENTER")
    val:SetWidth(90)
    local minus = UI.Button(f, "-", 22, 20, "ghost")
    local plus = UI.Button(f, "+", 22, 20, "ghost")
    plus:SetPoint("RIGHT")
    val:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    minus:SetPoint("RIGHT", val, "LEFT", -4, 0)
    local function idx()
        local cur = get()
        local best, bd = 1, math.huge
        for i, v in ipairs(values) do
            local d = math.abs(v - cur)
            if d < bd then best, bd = i, d end
        end
        return best
    end
    function f:Refresh() val:SetText(fmtFn(get())) end
    minus:SetScript("OnClick", function() set(values[math.max(1, idx() - 1)]); f:Refresh() end)
    plus:SetScript("OnClick", function() set(values[math.min(#values, idx() + 1)]); f:Refresh() end)
    f:Refresh()
    return f
end

-- Choix segmenté (filtres)
function UI.Segmented(parent, options, onChange, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(24)
    f.buttons = {}
    local x = 0
    for i, opt in ipairs(options) do
        local b = CreateFrame("Button", nil, f)
        local w = width or (opt.w or 90)
        b:SetSize(w, 24)
        b:SetPoint("LEFT", x, 0)
        x = x + w + 2
        b.bg = UI.Tex(b, "BACKGROUND", 0.14, 0.16, 0.2, 1)
        b.bg:SetAllPoints()
        b.label = UI.Text(b, 11, R.text, "CENTER")
        b.label:SetPoint("CENTER")
        b.label:SetText(opt.label)
        b.value = opt.value
        b:SetScript("OnClick", function() f:Select(opt.value, true) end)
        b:SetScript("OnEnter", function(self) if f.value ~= self.value then self.bg:SetColorTexture(0.19, 0.22, 0.27, 1) end end)
        b:SetScript("OnLeave", function(self) if f.value ~= self.value then self.bg:SetColorTexture(0.14, 0.16, 0.2, 1) end end)
        f.buttons[i] = b
    end
    f:SetWidth(x)
    function f:Select(value, fire)
        self.value = value
        for _, b in ipairs(self.buttons) do
            if b.value == value then
                b.bg:SetColorTexture(1, 0.78, 0.1, 1)
                b.label:SetTextColor(0.08, 0.07, 0.04)
            else
                b.bg:SetColorTexture(0.14, 0.16, 0.2, 1)
                b.label:SetTextColor(R.text[1], R.text[2], R.text[3])
            end
        end
        if fire and onChange then onChange(value) end
    end
    return f
end

-- Champ de recherche
function UI.Search(parent, width, placeholder, onChange)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width or 180, 24)
    e:SetAutoFocus(false)
    e:SetFont(FONT, 12, "")
    e:SetTextColor(1, 1, 1)
    e:SetTextInsets(8, 8, 0, 0)
    UI.Fill(e, {0.14, 0.16, 0.2})
    local ph = UI.Text(e, 12, R.muted)
    ph:SetPoint("LEFT", 8, 0)
    ph:SetText(placeholder or "Rechercher...")
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    e:SetScript("OnTextChanged", function(self)
        ph:SetShown(self:GetText() == "")
        if onChange then onChange(self:GetText()) end
    end)
    return e
end

-- Tuile de statistique
function UI.Card(parent, w, h, title)
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(w, h)
    UI.Fill(c, R.panel2)
    c.accent = UI.Tex(c, "ARTWORK", 1, 0.78, 0.1, 1)
    c.accent:SetPoint("TOPLEFT")
    c.accent:SetPoint("BOTTOMLEFT")
    c.accent:SetWidth(2)
    c.title = UI.Text(c, 10, R.muted)
    c.title:SetPoint("TOPLEFT", 12, -9)
    c.title:SetText((title or ""):upper())
    c.value = UI.Text(c, 17, R.text)
    c.value:SetPoint("TOPLEFT", 12, -24)
    c.sub = UI.Text(c, 11, R.muted)
    c.sub:SetPoint("TOPLEFT", 12, -46)
    c.sub:SetWidth(w - 20)
    return c
end

------------------------------------------------------------------------
-- Tableau virtualisé, colonnes triables
-- cols : {key, label, width, align, text = function(row) -> texte, sort = function(row) -> valeur}
------------------------------------------------------------------------
local ROW_H = 26

function UI.Table(parent, cols, opts)
    opts = opts or {}
    local t = CreateFrame("Frame", nil, parent)
    t.cols, t.data, t.offset = cols, {}, 0
    t.sortCol, t.sortDesc = opts.sortCol, opts.sortDesc ~= false

    local header = CreateFrame("Frame", nil, t)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(24)
    UI.Fill(header, {0.11, 0.125, 0.155})
    t.header = header
    t.hcells = {}

    local body = CreateFrame("Frame", nil, t)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    body:SetPoint("BOTTOMRIGHT", -8, 0)
    body:EnableMouseWheel(true)
    t.body = body

    -- barre de défilement
    local bar = CreateFrame("Frame", nil, t)
    bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetWidth(4)
    UI.Fill(bar, {1, 1, 1, 0.04})
    local thumb = UI.Tex(bar, "ARTWORK", 1, 0.78, 0.1, 0.6)
    thumb:SetWidth(4)
    t.bar, t.thumb = bar, thumb

    local empty = UI.Text(body, 12, R.muted, "CENTER")
    empty:SetPoint("TOP", 0, -40)
    empty:SetWidth(420)
    empty:SetWordWrap(true)
    t.emptyText = empty

    -- en-têtes
    local function layoutHeader()
        local x = 8
        for i, c in ipairs(cols) do
            local h = t.hcells[i]
            if not h then
                h = CreateFrame("Button", nil, header)
                h:SetHeight(24)
                h.text = UI.Text(h, 10, R.muted, c.align or "LEFT")
                h.text:SetAllPoints()
                h:SetScript("OnClick", function()
                    if not c.sort then return end
                    if t.sortCol == i then t.sortDesc = not t.sortDesc else t.sortCol, t.sortDesc = i, true end
                    t:Refresh()
                end)
                t.hcells[i] = h
            end
            h:ClearAllPoints()
            h:SetPoint("LEFT", x, 0)
            local w = c.width
            if w == "fill" then
                w = math.max(60, (t:GetWidth() - 16) - t.fixedWidth)
            end
            h:SetWidth(w)
            c.x, c.w = x, w
            local arrow = ""
            if t.sortCol == i then arrow = t.sortDesc and " v" or " ^" end
            h.text:SetText((c.label or ""):upper() .. arrow)
            x = x + w + 6
        end
    end
    t.fixedWidth = 0
    for _, c in ipairs(cols) do if c.width ~= "fill" then t.fixedWidth = t.fixedWidth + c.width + 6 end end

    t.rows = {}
    local function getRow(i)
        local r = t.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, body)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.stripe = UI.Tex(r, "BACKGROUND", 1, 1, 1, (i % 2 == 0) and 0.025 or 0)
        r.stripe:SetAllPoints()
        r.hl = UI.Tex(r, "HIGHLIGHT", 1, 0.82, 0, 0.07)
        r.hl:SetAllPoints()
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.cells = {}
        r:SetScript("OnEnter", function(self)
            if self.data and opts.onEnter then opts.onEnter(self, self.data) end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", function(self, button)
            if self.data and opts.onClick then opts.onClick(self, self.data, button) end
        end)
        t.rows[i] = r
        return r
    end

    local function visibleCount()
        return math.max(1, math.floor(body:GetHeight() / ROW_H))
    end

    function t:Render()
        layoutHeader()
        local n = visibleCount()
        local maxOff = math.max(0, #t.data - n)
        if t.offset > maxOff then t.offset = maxOff end
        for i = 1, n do
            local r = getRow(i)
            local d = t.data[t.offset + i]
            if d then
                r.data = d
                for ci, c in ipairs(cols) do
                    local cell = r.cells[ci]
                    if not cell then
                        if c.button then
                            cell = UI.Button(r, c.button, c.width, 20, c.buttonStyle or "primary")
                            cell:SetScript("OnClick", function(self) if self:GetParent().data then c.onClick(self:GetParent().data) end end)
                        else
                            cell = UI.Text(r, c.size or 12, R.text, c.align or "LEFT")
                        end
                        r.cells[ci] = cell
                    end
                    cell:ClearAllPoints()
                    if c.button then
                        cell:SetPoint("LEFT", r, "LEFT", c.x, 0)
                        cell:SetWidth(c.w)
                        local show, label, enabled = true, c.button, true
                        if c.state then show, label, enabled = c.state(d) end
                        cell:SetShown(show)
                        if label then cell:SetText(label) end
                        cell:SetEnabled(enabled ~= false)
                    else
                        local x = c.x
                        if c.icon then
                            r.icon:ClearAllPoints()
                            r.icon:SetPoint("LEFT", r, "LEFT", x, 0)
                            r.icon:SetTexture(c.icon(d))
                            r.icon:Show()
                            x = x + 24
                            cell:SetWidth(c.w - 24)
                        else
                            cell:SetWidth(c.w)
                        end
                        cell:SetPoint("LEFT", r, "LEFT", x, 0)
                        cell:SetText(c.text(d) or "")
                    end
                end
                r:Show()
            else
                r.data = nil
                r:Hide()
            end
        end
        for i = n + 1, #t.rows do t.rows[i]:Hide() end
        -- barre
        local total = #t.data
        if total > n then
            local h = bar:GetHeight()
            local th = math.max(20, h * n / total)
            thumb:SetHeight(th)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", bar, "TOP", 0, -(h - th) * (t.offset / math.max(1, total - n)))
            thumb:Show()
        else
            thumb:Hide()
        end
        empty:SetShown(total == 0)
    end

    function t:SetData(data, emptyMsg)
        t.data = data or {}
        if emptyMsg then empty:SetText(emptyMsg) end
        t:Refresh()
    end

    function t:Refresh()
        local c = t.sortCol and cols[t.sortCol]
        if c and c.sort then
            local desc = t.sortDesc
            table.sort(t.data, function(a, b)
                local va, vb = c.sort(a), c.sort(b)
                if va == vb then return false end
                if va == nil then return false end
                if vb == nil then return true end
                if desc then return va > vb end
                return va < vb
            end)
        end
        t:Render()
    end

    body:SetScript("OnMouseWheel", function(_, delta)
        local step = IsShiftKeyDown() and 10 or 3
        t.offset = math.max(0, t.offset - delta * step)
        t:Render()
    end)
    t:SetScript("OnSizeChanged", function() t:Render() end)
    return t
end

-- Infobulle d'objet sur une ligne
-- Action commune à toutes les listes d'objets
function XG.RowClick(id, key, button)
    if not id then return end
    if IsShiftKeyDown() then UI.LinkItem(id) return end
    if button == "RightButton" or not XG.ahOpen then
        XG:ShowItem(id, key)
    else
        XG:SearchAH(id)
    end
end

function UI.ClickHint()
    if XG.ahOpen then
        return XG.C.grey .. "Clic : chercher à l'HV  ·  Clic droit : courbe des prix  ·  Maj+clic : lien|r"
    end
    return XG.C.grey .. "Clic : courbe des prix  ·  Maj+clic : lien dans la discussion|r"
end

function UI.ItemTooltip(owner, id, key, extra, noHint)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local link = "item:" .. id
    local suffix = key and tostring(key):match(":(%-?%d+)$")
    if suffix then link = "item:" .. id .. ":0:0:0:0:0:" .. suffix end
    GameTooltip:SetHyperlink(link)
    if extra then
        GameTooltip:AddLine(" ")
        for _, l in ipairs(extra) do GameTooltip:AddLine(l, 1, 1, 1, true) end
    end
    if not noHint then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(UI.ClickHint())
    end
    GameTooltip:Show()
end

-- Maj+clic : lien dans la discussion
function UI.LinkItem(id)
    local info = XG.ItemInfo(id)
    if info and info.link and ChatEdit_InsertLink then ChatEdit_InsertLink(info.link) end
end
