-- GUI Module – BRM5 PVE
-- Style LizardHub V2 : fond noir, accent jaune, barre slim, boutons ON/OFF
-- Rework complet : Architecture modulaire, sections rétractables, keybinds

local GUI = {}

GUI.screenGui       = nil
GUI.mainFrame       = nil
GUI.modalOverlay    = nil
GUI.cursorIndicator = nil
GUI.toggleButton    = nil
GUI.tabButtons      = {}
GUI.tabs            = {}

-- ── Palette ──────────────────────────────────────────────────────────────────
local C = {
bg                = Color3.fromRGB(8, 8, 10),
    header            = Color3.fromRGB(12, 12, 15),
    catPanel          = Color3.fromRGB(16, 16, 20),
    catBadge          = Color3.fromRGB(10, 10, 12),
    catSelected       = Color3.fromRGB(45, 25, 80),
    cardBg            = Color3.fromRGB(14, 14, 18),
    collapseBg        = Color3.fromRGB(18, 18, 24),
    collapseHeader    = Color3.fromRGB(22, 22, 30),
    btnOn             = Color3.fromRGB(130, 50, 255),
    btnOff            = Color3.fromRGB(25, 25, 30),
    btnHome           = Color3.fromRGB(35, 35, 40),
    btnUnload         = Color3.fromRGB(150, 40, 40),
    btnKeybind        = Color3.fromRGB(25, 25, 30), -- Harmonisé avec textbox/inactive
    btnKeybindActive  = Color3.fromRGB(25, 15, 45), -- Basé sur votre scriptHover
    text              = Color3.fromRGB(230, 230, 230),
    textDim           = Color3.fromRGB(90, 90, 100),
    accent            = Color3.fromRGB(140, 60, 255),
    accentDim         = Color3.fromRGB(70, 30, 125), -- Version sombre de l'accent
    sliderTrack       = Color3.fromRGB(25, 25, 30),
    infoText          = Color3.fromRGB(80, 80, 90),
    separator         = Color3.fromRGB(35, 35, 45),
}

-- ── Variables d'état ─────────────────────────────────────────────────────────
local isAnimating   = false
local menuOpen      = true
local savedPosition = nil
local targetSize    = UDim2.new(0, 640, 0, 430)

-- ── Registries modulaires ────────────────────────────────────────────────────
local TAB_REGISTRY     = {}   -- { name, icon, builder, pos }
local KEYBIND_REGISTRY = {}   -- { id, label, key, callback }

-- ── Utilitaires bas niveau ───────────────────────────────────────────────────

local function mkCorner(parent, r)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, r or 8)
end

local function mkStroke(parent, color, thickness)
    local s = Instance.new("UIStroke", parent)
    s.Color           = color or C.separator
    s.Thickness       = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

local function updateFloatBtnText(btn, visible)
    if btn then btn.Text = visible and "▼  Hide GUI" or "▲  Open GUI" end
end

-- ── API publique : enregistrement modulaire ───────────────────────────────────

function GUI:registerTab(name, icon, builderFn, position)
    table.insert(TAB_REGISTRY, {
        name    = name,
        icon    = icon or "",
        builder = builderFn,
        pos     = position or (#TAB_REGISTRY + 1),
    })
    table.sort(TAB_REGISTRY, function(a, b) return (a.pos or 99) < (b.pos or 99) end)
end

function GUI:registerKeybind(id, label, defaultKey, callback)
    KEYBIND_REGISTRY[id] = {
        id       = id,
        label    = label,
        key      = defaultKey or Enum.KeyCode.Unknown,
        callback = callback,
    }
end

-- Bloque le listener global pendant qu'un bouton keybind est en mode écoute
local anyListening = false

local function setupKeybindListeners(services)
    if not services or not services.UserInputService then return end
    services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if anyListening  then return end   -- ne pas déclencher pendant une réassignation
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        for _, kb in pairs(KEYBIND_REGISTRY) do
            if input.KeyCode == kb.key
                and kb.key ~= Enum.KeyCode.Unknown
                and kb.callback then
                kb.callback()
            end
        end
    end)
end

-- ── Noms de touches (utilisé par les boutons keybind inline) ─────────────────

local KEYCODE_NAMES = {
    [Enum.KeyCode.Unknown]      = "—",
    [Enum.KeyCode.LeftAlt]      = "LAlt",   [Enum.KeyCode.RightAlt]     = "RAlt",
    [Enum.KeyCode.LeftControl]  = "LCtrl",  [Enum.KeyCode.RightControl] = "RCtrl",
    [Enum.KeyCode.LeftShift]    = "LShift", [Enum.KeyCode.RightShift]   = "RShift",
    [Enum.KeyCode.Tab]          = "Tab",    [Enum.KeyCode.CapsLock]     = "Caps",
    [Enum.KeyCode.Space]        = "Space",  [Enum.KeyCode.Return]       = "Enter",
    [Enum.KeyCode.Delete]       = "Del",    [Enum.KeyCode.Insert]       = "Ins",
    [Enum.KeyCode.Home]         = "Home",   [Enum.KeyCode.End]          = "End",
    [Enum.KeyCode.PageUp]       = "PgUp",   [Enum.KeyCode.PageDown]     = "PgDn",
    [Enum.KeyCode.F1]  = "F1",  [Enum.KeyCode.F2]  = "F2",  [Enum.KeyCode.F3]  = "F3",
    [Enum.KeyCode.F4]  = "F4",  [Enum.KeyCode.F5]  = "F5",  [Enum.KeyCode.F6]  = "F6",
    [Enum.KeyCode.F7]  = "F7",  [Enum.KeyCode.F8]  = "F8",  [Enum.KeyCode.F9]  = "F9",
    [Enum.KeyCode.F10] = "F10", [Enum.KeyCode.F11] = "F11", [Enum.KeyCode.F12] = "F12",
}

local function getKeyName(keyCode)
    if KEYCODE_NAMES[keyCode] then return KEYCODE_NAMES[keyCode] end
    local s = tostring(keyCode)
    return s:match("Enum%.KeyCode%.(.+)") or s
end

-- ── Primitives UI ─────────────────────────────────────────────────────────────

local function newTabPage(container)
    local f = Instance.new("ScrollingFrame", container)
    f.Size                = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible             = false
    f.ScrollBarThickness  = 2
    f.ScrollBarImageColor3 = C.accent
    f.CanvasSize          = UDim2.new(0, 0, 0, 0)
    f.AutomaticCanvasSize = Enum.AutomaticSize.Y
    f.BorderSizePixel     = 0
    f.ClipsDescendants    = true
    local l = Instance.new("UIListLayout", f)
    l.Padding             = UDim.new(0, 6)
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.SortOrder           = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", f)
    pad.PaddingTop    = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 6)
    pad.PaddingLeft   = UDim.new(0, 4)
    pad.PaddingRight  = UDim.new(0, 4)
    return f
end

local function newCard(parent, h)
    local f = Instance.new("Frame", parent)
    f.Size             = UDim2.new(1, -10, 0, h or 48)
    f.BackgroundColor3 = C.cardBg
    f.BorderSizePixel  = 0
    mkCorner(f, 8)
    return f
end

local function newSection(parent, text, color)
    local f = Instance.new("Frame", parent)
    f.Size             = UDim2.new(1, -10, 0, 24)
    f.BackgroundColor3 = C.catBadge
    f.BorderSizePixel  = 0
    mkCorner(f, 5)
    local l = Instance.new("TextLabel", f)
    l.Size             = UDim2.new(1, -10, 1, 0)
    l.Position         = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text             = text
    l.TextColor3       = color or C.accent
    l.Font             = Enum.Font.GothamBold
    l.TextSize         = 10
    l.TextXAlignment   = Enum.TextXAlignment.Left
end

local function newCardLabel(card, text, color)
    local l = Instance.new("TextLabel", card)
    l.Size             = UDim2.new(1, -110, 1, 0)
    l.Position         = UDim2.new(0, 14, 0, 0)
    l.BackgroundTransparency = 1
    l.Text             = text
    l.TextColor3       = color or C.text
    l.Font             = Enum.Font.GothamSemibold
    l.TextSize         = 13
    l.TextXAlignment   = Enum.TextXAlignment.Left
    l.TextYAlignment   = Enum.TextYAlignment.Center
    return l
end

local function newInfoText(parent, text)
    local l = Instance.new("TextLabel", parent)
    l.Size             = UDim2.new(1, -10, 0, 0)
    l.AutomaticSize    = Enum.AutomaticSize.Y
    l.BackgroundTransparency = 1
    l.Text             = text
    l.TextColor3       = C.infoText
    l.Font             = Enum.Font.Gotham
    l.TextSize         = 11
    l.TextWrapped      = true
    l.TextXAlignment   = Enum.TextXAlignment.Left
    l.TextYAlignment   = Enum.TextYAlignment.Top
    return l
end

local function newTogglePill(card, initialActive, callback, rightOffset)
    rightOffset = rightOffset or 80
    local btn = Instance.new("TextButton", card)
    btn.Size             = UDim2.new(0, 62, 0, 26)
    btn.Position         = UDim2.new(1, -(rightOffset), 0.5, -13)
    btn.BackgroundColor3 = initialActive and C.btnOn or C.btnOff
    btn.Text             = initialActive and "ON" or "OFF"
    btn.TextColor3       = C.text
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 12
    btn.AutoButtonColor  = false
    btn.BorderSizePixel  = 0
    mkCorner(btn, 6)
    local active = initialActive and true or false
    btn.MouseButton1Click:Connect(function()
        active               = not active
        btn.BackgroundColor3 = active and C.btnOn or C.btnOff
        btn.Text             = active and "ON" or "OFF"
        callback(active)
    end)
    return btn
end

-- Bouton keybind discret inline
local function newInlineKeybindBtn(card, keybindId, services, rightOffset)
    local kb = KEYBIND_REGISTRY[keybindId]
    if not kb then return end
    rightOffset = rightOffset or 148

    local btn = Instance.new("TextButton", card)
    btn.Size                   = UDim2.new(0, 34, 0, 20)
    btn.Position               = UDim2.new(1, -rightOffset, 0.5, -10)
    btn.BackgroundColor3       = Color3.fromRGB(20, 20, 26)
    btn.BackgroundTransparency = 0.2
    btn.Text                   = getKeyName(kb.key) == "—" and "·" or getKeyName(kb.key)
    btn.TextColor3             = Color3.fromRGB(100, 100, 120)
    btn.Font                   = Enum.Font.GothamBold
    btn.TextSize               = 9
    btn.AutoButtonColor        = false
    btn.BorderSizePixel        = 0
    mkCorner(btn, 4)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(45, 45, 60); stroke.Thickness = 1

    local listening = false
    local function setIdle()
        local name = getKeyName(kb.key)
        btn.Text             = name == "—" and "·" or name
        btn.TextColor3       = Color3.fromRGB(100, 100, 120)
        btn.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
        stroke.Color         = Color3.fromRGB(45, 45, 60)
        listening    = false
        anyListening = false
    end
    local function setListening()
        btn.Text             = "···"
        btn.TextColor3       = C.accent
        btn.BackgroundColor3 = Color3.fromRGB(30, 25, 10)
        stroke.Color         = C.accentDim
        listening    = true
        anyListening = true
    end
    btn.MouseButton1Click:Connect(function()
        if listening then setIdle(); return end
        setListening()
        local conn
        conn = services.UserInputService.InputBegan:Connect(function(input, gp)
            if not listening then conn:Disconnect(); return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if input.KeyCode == Enum.KeyCode.Escape then setIdle(); conn:Disconnect(); return end
            kb.key = input.KeyCode
            setIdle(); conn:Disconnect()
        end)
    end)
    return btn
end

-- ── newToggleCard simple : [label] [ON/OFF]
local function newToggleCard(parent, text, initialActive, callback, keybindId, services)
    local card = newCard(parent, 48)
    local lbl = Instance.new("TextLabel", card)
    lbl.Size             = UDim2.new(1, -100, 1, 0)
    lbl.Position         = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text
    lbl.TextColor3       = C.text
    lbl.Font             = Enum.Font.GothamSemibold
    lbl.TextSize         = 13
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.TextYAlignment   = Enum.TextYAlignment.Center
    newTogglePill(card, initialActive, callback, 80)
    if keybindId and services then
        newInlineKeybindBtn(card, keybindId, services, 148)
    end
end

-- ── newToggleWithSettings : [label] [ON/OFF] [kb] [⚙]
-- builderFn(addFn) — appelée avec la fonction add() du collapsible interne
-- Retourne addFn pour y ajouter des éléments depuis le builder de l'onglet
local function newToggleWithSettings(parent, text, initialActive, callback, keybindId, services, builderFn)
    -- Carte header (légèrement plus haute pour le ⚙)
    local card = newCard(parent, 48)
    card.BackgroundColor3 = C.cardBg

    -- Label
    local lbl = Instance.new("TextLabel", card)
    lbl.Size             = UDim2.new(1, -165, 1, 0)
    lbl.Position         = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text
    lbl.TextColor3       = C.text
    lbl.Font             = Enum.Font.GothamSemibold
    lbl.TextSize         = 13
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.TextYAlignment   = Enum.TextYAlignment.Center

    -- ON/OFF
    newTogglePill(card, initialActive, callback, 116)

    -- Keybind discret
    if keybindId and services then
        newInlineKeybindBtn(card, keybindId, services, 188)
    end

    -- Bouton ⚙
    local gearBtn = Instance.new("TextButton", card)
    gearBtn.Size             = UDim2.new(0, 26, 0, 26)
    gearBtn.Position         = UDim2.new(1, -32, 0.5, -13)
    gearBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    gearBtn.Text             = "⚙"
    gearBtn.TextColor3       = Color3.fromRGB(90, 90, 110)
    gearBtn.Font             = Enum.Font.GothamBold
    gearBtn.TextSize         = 13
    gearBtn.AutoButtonColor  = false
    gearBtn.BorderSizePixel  = 0
    mkCorner(gearBtn, 5)
    mkStroke(gearBtn, Color3.fromRGB(38, 38, 50), 1)

    -- Collapsible de settings (fermé par défaut)
    local settingsOpen = false

    local settingsFrame = Instance.new("Frame", parent)
    settingsFrame.Size             = UDim2.new(1, -10, 0, 0)
    settingsFrame.AutomaticSize    = Enum.AutomaticSize.Y
    settingsFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 21)
    settingsFrame.BorderSizePixel  = 0
    settingsFrame.Visible          = false
    mkCorner(settingsFrame, 7)
    mkStroke(settingsFrame, Color3.fromRGB(30, 30, 42), 1)

    -- Ligne accent gauche dans le settingsFrame
    local accentBar = Instance.new("Frame", settingsFrame)
    accentBar.Size             = UDim2.new(0, 2, 1, -10)
    accentBar.Position         = UDim2.new(0, 0, 0, 5)
    accentBar.BackgroundColor3 = C.accentDim
    accentBar.BackgroundTransparency = 0.5
    accentBar.BorderSizePixel  = 0
    mkCorner(accentBar, 2)

    local contentFrame = Instance.new("Frame", settingsFrame)
    contentFrame.Size             = UDim2.new(1, -8, 0, 0)
    contentFrame.Position         = UDim2.new(0, 8, 0, 0)
    contentFrame.AutomaticSize    = Enum.AutomaticSize.Y
    contentFrame.BackgroundTransparency = 1

    local contentList = Instance.new("UIListLayout", contentFrame)
    contentList.Padding             = UDim.new(0, 4)
    contentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    contentList.SortOrder           = Enum.SortOrder.LayoutOrder

    local pad = Instance.new("UIPadding", contentFrame)
    pad.PaddingTop = UDim.new(0, 5); pad.PaddingBottom = UDim.new(0, 5)

    -- Toggle ⚙
    gearBtn.MouseButton1Click:Connect(function()
        settingsOpen          = not settingsOpen
        settingsFrame.Visible = settingsOpen
        gearBtn.TextColor3    = settingsOpen and C.accent or Color3.fromRGB(90, 90, 110)
        local s = Instance.new("UIStroke"); s.Parent = gearBtn
        s.Color     = settingsOpen and C.accentDim or Color3.fromRGB(38, 38, 50)
        s.Thickness = 1
    end)

    -- Fonction add retournée pour remplir le panel settings
    local function addItem(fnOrInst, ...)
        if type(fnOrInst) == "function" then
            fnOrInst(contentFrame, ...)
        elseif typeof(fnOrInst) == "Instance" then
            fnOrInst.Parent = contentFrame
        end
    end

    if builderFn then builderFn(addItem) end
    return addItem
end

local function newSlider(parent, labelText, initVal, maxVal, callback, services)
    local card = newCard(parent, 54)

    local lbl = Instance.new("TextLabel", card)
    lbl.Size             = UDim2.new(1, -16, 0, 18)
    lbl.Position         = UDim2.new(0, 10, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text             = labelText .. ":  " .. initVal
    lbl.TextColor3       = C.text
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 12
    lbl.TextXAlignment   = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", card)
    track.Position       = UDim2.new(0, 10, 0, 32)
    track.Size           = UDim2.new(1, -20, 0, 6)
    track.BackgroundColor3 = C.sliderTrack
    track.BorderSizePixel = 0
    mkCorner(track, 10)

    local fill = Instance.new("Frame", track)
    fill.Size            = UDim2.new(maxVal > 0 and (initVal / maxVal) or 0, 0, 1, 0)
    fill.BackgroundColor3 = C.accent
    fill.BorderSizePixel  = 0
    mkCorner(fill, 10)

    local thumb = Instance.new("Frame", track)
    thumb.Size           = UDim2.new(0, 12, 0, 12)
    thumb.AnchorPoint    = Vector2.new(0.5, 0.5)
    thumb.Position       = UDim2.new(maxVal > 0 and (initVal / maxVal) or 0, 0, 0.5, 0)
    thumb.BackgroundColor3 = C.text
    thumb.BorderSizePixel = 0
    mkCorner(thumb, 10)

    local dragging = false
    local function update()
        local mx = services.UserInputService:GetMouseLocation().X
        local p  = math.clamp((mx - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v  = math.floor(p * maxVal + 0.5)
        fill.Size      = UDim2.new(p, 0, 1, 0)
        thumb.Position = UDim2.new(p, 0, 0.5, 0)
        lbl.Text       = labelText .. ":  " .. v
        callback(v)
    end

    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update() end
    end)
    services.UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    services.RunService.RenderStepped:Connect(function()
        if dragging then update() end
    end)
end

-- ── Keybind Button (onglet Keybinds dédié) ───────────────────────────────────

local function newKeybindButton(card, keybindId, services)
    local kb = KEYBIND_REGISTRY[keybindId]
    if not kb then return end

    local btn = Instance.new("TextButton", card)
    btn.Size             = UDim2.new(0, 78, 0, 28)
    btn.Position         = UDim2.new(1, -88, 0.5, -14)
    btn.BackgroundColor3 = C.btnKeybind
    btn.Text             = "[" .. getKeyName(kb.key) .. "]"
    btn.TextColor3       = C.accent
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 11
    btn.AutoButtonColor  = false
    btn.BorderSizePixel  = 0
    mkCorner(btn, 6)
    mkStroke(btn, C.accentDim, 1)

    local listening = false
    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening            = true
        btn.Text             = "[ ... ]"
        btn.TextColor3       = C.text
        btn.BackgroundColor3 = C.btnKeybindActive

        local conn
        conn = services.UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                kb.key               = input.KeyCode
                btn.Text             = "[" .. getKeyName(kb.key) .. "]"
                btn.TextColor3       = C.accent
                btn.BackgroundColor3 = C.btnKeybind
                listening = false
                conn:Disconnect()
            end
        end)
    end)
    return btn
end

local function newKeybindCard(parent, text, keybindId, services)
    local card = newCard(parent, 48)
    newCardLabel(card, text)
    newKeybindButton(card, keybindId, services)
    return card
end

-- ── Section rétractable (Collapsible) ─────────────────────────────────────────
-- Retourne une fonction add(builderFn, ...) ou add(frameInstance)

local function newCollapsible(parent, title, initialOpen, accentColor)
    accentColor = accentColor or C.accent
    local open  = (initialOpen == nil) and true or initialOpen

    local container = Instance.new("Frame", parent)
    container.Size             = UDim2.new(1, -10, 0, 0)
    container.AutomaticSize    = Enum.AutomaticSize.Y
    container.BackgroundColor3 = C.collapseBg
    container.BorderSizePixel  = 0
    mkCorner(container, 8)
    mkStroke(container, C.separator, 1)

    local headerBtn = Instance.new("TextButton", container)
    headerBtn.Size             = UDim2.new(1, 0, 0, 34)
    headerBtn.BackgroundColor3 = C.collapseHeader
    headerBtn.BorderSizePixel  = 0
    headerBtn.Text             = ""
    headerBtn.AutoButtonColor  = false
    mkCorner(headerBtn, 8)

    local accentBar = Instance.new("Frame", headerBtn)
    accentBar.Size             = UDim2.new(0, 2, 0, 16)
    accentBar.Position         = UDim2.new(0, 8, 0.5, -8)
    accentBar.BackgroundColor3 = accentColor
    accentBar.BorderSizePixel  = 0
    mkCorner(accentBar, 2)

    local titleLbl = Instance.new("TextLabel", headerBtn)
    titleLbl.Size             = UDim2.new(1, -60, 1, 0)
    titleLbl.Position         = UDim2.new(0, 18, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text             = title
    titleLbl.TextColor3       = C.text
    titleLbl.Font             = Enum.Font.GothamBold
    titleLbl.TextSize         = 12
    titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
    titleLbl.TextYAlignment   = Enum.TextYAlignment.Center

    local arrowLbl = Instance.new("TextLabel", headerBtn)
    arrowLbl.Size             = UDim2.new(0, 24, 1, 0)
    arrowLbl.Position         = UDim2.new(1, -30, 0, 0)
    arrowLbl.BackgroundTransparency = 1
    arrowLbl.Text             = open and "▲" or "▼"
    arrowLbl.TextColor3       = accentColor
    arrowLbl.Font             = Enum.Font.GothamBold
    arrowLbl.TextSize         = 10
    arrowLbl.TextXAlignment   = Enum.TextXAlignment.Center
    arrowLbl.TextYAlignment   = Enum.TextYAlignment.Center

    local separator = Instance.new("Frame", container)
    separator.Size             = UDim2.new(1, -16, 0, 1)
    separator.Position         = UDim2.new(0, 8, 0, 34)
    separator.BackgroundColor3 = C.separator
    separator.BorderSizePixel  = 0
    separator.Visible          = open

    local contentFrame = Instance.new("Frame", container)
    contentFrame.Size             = UDim2.new(1, 0, 0, 0)
    contentFrame.Position         = UDim2.new(0, 0, 0, 36)
    contentFrame.AutomaticSize    = Enum.AutomaticSize.Y
    contentFrame.BackgroundTransparency = 1
    contentFrame.Visible          = open
    contentFrame.ClipsDescendants = false

    local contentList = Instance.new("UIListLayout", contentFrame)
    contentList.Padding             = UDim.new(0, 4)
    contentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    contentList.SortOrder           = Enum.SortOrder.LayoutOrder

    local bottomPad = Instance.new("UIPadding", contentFrame)
    bottomPad.PaddingBottom = UDim.new(0, 6)
    bottomPad.PaddingTop    = UDim.new(0, 4)

    headerBtn.MouseButton1Click:Connect(function()
        open                 = not open
        contentFrame.Visible = open
        separator.Visible    = open
        arrowLbl.Text        = open and "▲" or "▼"
    end)

    return function(builderFnOrInstance, ...)
        if type(builderFnOrInstance) == "function" then
            builderFnOrInstance(contentFrame, ...)
        elseif typeof(builderFnOrInstance) == "Instance" then
            builderFnOrInstance.Parent = contentFrame
        end
    end
end

-- ── Helper : aperçu couleur (carte + carré de prévisualisation) ───────────────

local function newColorPreviewCard(parent, labelText, initialColor)
    local card = newCard(parent, 34)
    local lbl  = newCardLabel(card, labelText, C.textDim)
    lbl.TextSize = 11
    local preview = Instance.new("Frame", card)
    preview.Size             = UDim2.new(0, 50, 0, 20)
    preview.Position         = UDim2.new(1, -60, 0.5, -10)
    preview.BackgroundColor3 = initialColor
    preview.BorderSizePixel  = 0
    mkCorner(preview, 5)
    return card, preview
end

-- ── GUI:init ──────────────────────────────────────────────────────────────────

function GUI:init(services, config, callbacks)
    -- Sécurité : si registerDefaultTabs() n'a pas été appelé, on le fait ici
    if #TAB_REGISTRY == 0 then
        self:registerDefaultTabs()
    end

    local localPlayer  = services.localPlayer
    local playerMouse  = localPlayer:GetMouse()
    local TweenService = services.TweenService or game:GetService("TweenService")

    setupKeybindListeners(services)

    -- ScreenGui
    self.screenGui = Instance.new("ScreenGui", localPlayer.PlayerGui)
    self.screenGui.Name           = "BRM5_PVE_GUI"
    self.screenGui.ResetOnSpawn   = false
    self.screenGui.DisplayOrder   = 9999
    self.screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Modal overlay
    local overlay = Instance.new("TextButton", self.screenGui)
    overlay.Name                   = "ModalOverlay"
    overlay.Size                   = UDim2.fromScale(1, 1)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel        = 0
    overlay.Text                   = ""
    overlay.AutoButtonColor        = false
    overlay.Modal                  = true
    overlay.Active                 = true
    overlay.Visible                = config.guiVisible
    self.modalOverlay = overlay

    -- Curseur personnalisé
    local cur = Instance.new("Frame", self.screenGui)
    cur.Name             = "CursorIndicator"
    cur.Size             = UDim2.fromOffset(10, 10)
    cur.AnchorPoint      = Vector2.new(0.5, 0.5)
    cur.BackgroundColor3 = C.text
    cur.BorderSizePixel  = 0
    cur.Visible          = config.guiVisible
    cur.ZIndex           = 100
    mkCorner(cur, 10)
    local cs = Instance.new("UIStroke", cur)
    cs.Color = Color3.new(0, 0, 0); cs.Thickness = 1.5
    self.cursorIndicator = cur

    -- Bouton flottant Open/Hide
    local floatBtn = Instance.new("TextButton", self.screenGui)
    floatBtn.Name             = "GuiToggleButton"
    floatBtn.Size             = UDim2.fromOffset(120, 32)
    floatBtn.Position         = UDim2.new(0, 16, 0.5, -16)
    floatBtn.BackgroundColor3 = C.btnHome
    floatBtn.BorderSizePixel  = 0
    floatBtn.TextColor3       = C.text
    floatBtn.Font             = Enum.Font.GothamBold
    floatBtn.TextSize         = 12
    floatBtn.ZIndex           = 101
    mkCorner(floatBtn, 6)
    self.toggleButton = floatBtn
    updateFloatBtnText(floatBtn, config.guiVisible)
    floatBtn.MouseButton1Click:Connect(function()
        if callbacks.onVisibilityToggle then callbacks.onVisibilityToggle()
        else self:toggleVisibility(TweenService) end
    end)

    -- ── Fenêtre principale ────────────────────────────────────────────────────
    local main = Instance.new("Frame", self.screenGui)
    main.Name             = "MainFrame"
    main.Size             = targetSize
    main.Position         = UDim2.new(0.5, -320, 0.5, -215)
    main.BackgroundColor3 = C.bg
    main.BorderSizePixel  = 0
    main.Active           = true
    main.Visible          = config.guiVisible
    main.ClipsDescendants = true
    mkCorner(main, 12)
    self.mainFrame = main

    savedPosition = main.Position
    menuOpen      = config.guiVisible

    -- ── Header ────────────────────────────────────────────────────────────────
    local header = Instance.new("Frame", main)
    header.Name             = "Header"
    header.Size             = UDim2.new(1, 0, 0, 60)
    header.BackgroundColor3 = C.header
    header.BorderSizePixel  = 0
    header.Active           = true
    mkCorner(header, 12)

    local hFill = Instance.new("Frame", header)
    hFill.Size             = UDim2.new(1, 0, 0, 12)
    hFill.Position         = UDim2.new(0, 0, 1, -12)
    hFill.BackgroundColor3 = C.header
    hFill.BorderSizePixel  = 0

    local accentLine = Instance.new("Frame", header)
    accentLine.Size             = UDim2.new(1, 0, 0, 2)
    accentLine.Position         = UDim2.new(0, 0, 1, 0)
    accentLine.BackgroundColor3 = C.accent
    accentLine.BorderSizePixel  = 0
    local grad = Instance.new("UIGradient", accentLine)
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.8),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1,   0.8),
    })

    local titleIcon = Instance.new("ImageLabel", header)
    titleIcon.Size                = UDim2.new(0, 100, 0, 100)
    titleIcon.Position            = UDim2.new(0, -10, 0.5, -50)
    titleIcon.BackgroundTransparency = 1
    titleIcon.Image               = "rbxassetid://120005639715315"
    titleIcon.ZIndex              = 10

    local textContainer = Instance.new("Frame", header)
    textContainer.Size              = UDim2.new(1, -120, 1, 0)
    textContainer.Position          = UDim2.new(0, 70, 0, 0)
    textContainer.BackgroundTransparency = 1

    local title = Instance.new("TextLabel", textContainer)
    title.Size             = UDim2.new(1, 0, 0.5, 0)
    title.Position         = UDim2.new(0, 0, 0.15, 0)
    title.BackgroundTransparency = 1
    title.Text             = "- Lizard UI - V2 | BRM5 PVE "
    title.TextColor3       = C.text
    title.Font             = Enum.Font.GothamBold
    title.TextSize         = 16
    title.TextXAlignment   = Enum.TextXAlignment.Left

    local subCredits = Instance.new("TextLabel", textContainer)
    subCredits.Size             = UDim2.new(1, 0, 0.3, 0)
    subCredits.Position         = UDim2.new(0, 0, 0.6, 0)
    subCredits.BackgroundTransparency = 1
    subCredits.Text             = "UI BY FXTHai | "
    subCredits.TextColor3       = C.textDim
    subCredits.Font             = Enum.Font.Gotham
    subCredits.TextSize         = 15
    subCredits.TextXAlignment   = Enum.TextXAlignment.Left

    -- Bouton HOME
    local keyBadge = Instance.new("TextButton", header)
    keyBadge.Size             = UDim2.new(0, 70, 0, 28)
    keyBadge.Position         = UDim2.new(1, -125, 0.5, -14)
    keyBadge.BackgroundColor3 = C.btnHome
    keyBadge.BorderSizePixel  = 0
    keyBadge.Text             = "HOME"
    keyBadge.TextColor3       = C.text
    keyBadge.Font             = Enum.Font.GothamBold
    keyBadge.TextSize         = 11
    keyBadge.AutoButtonColor  = false
    mkCorner(keyBadge, 6)
    keyBadge.MouseButton1Click:Connect(function()
        if callbacks.onVisibilityToggle then callbacks.onVisibilityToggle()
        else self:toggleVisibility(TweenService) end
    end)

    -- Bouton Unload
    local unloadBtn = Instance.new("TextButton", header)
    unloadBtn.Size             = UDim2.new(0, 32, 0, 28)
    unloadBtn.Position         = UDim2.new(1, -44, 0.5, -14)
    unloadBtn.BackgroundColor3 = C.btnUnload
    unloadBtn.BorderSizePixel  = 0
    unloadBtn.Text             = "X"
    unloadBtn.TextColor3       = C.text
    unloadBtn.Font             = Enum.Font.GothamBold
    unloadBtn.TextSize         = 18
    unloadBtn.AutoButtonColor  = false
    mkCorner(unloadBtn, 6)
    unloadBtn.MouseButton1Click:Connect(callbacks.onUnload)

    -- ── Drag ─────────────────────────────────────────────────────────────────
    local dragging, dragInput, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and menuOpen and not isAnimating then
            dragging  = true
            dragStart = input.Position
            startPos  = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    services.RunService.RenderStepped:Connect(function()
        if dragging and dragInput and menuOpen and not isAnimating then
            local d = dragInput.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
            savedPosition = main.Position
        end
        if self.cursorIndicator then
            self.cursorIndicator.Position = UDim2.fromOffset(playerMouse.X, playerMouse.Y)
        end
    end)

    -- ── Resize ───────────────────────────────────────────────────────────────
    local MIN_W, MIN_H = 520, 340
    local resizing, resizeStart, startSize

    local resizeHandle = Instance.new("Frame", main)
    resizeHandle.Size                   = UDim2.new(0, 18, 0, 18)
    resizeHandle.Position               = UDim2.new(1, -18, 1, -18)
    resizeHandle.BackgroundColor3       = C.accent
    resizeHandle.BackgroundTransparency = 0.5
    resizeHandle.BorderSizePixel        = 0
    resizeHandle.ZIndex                 = 10
    mkCorner(resizeHandle, 4)

    local resizeIcon = Instance.new("TextLabel", resizeHandle)
    resizeIcon.Size               = UDim2.new(1, 0, 1, 0)
    resizeIcon.BackgroundTransparency = 1
    resizeIcon.Text               = "⋰"
    resizeIcon.TextColor3         = C.text
    resizeIcon.Font               = Enum.Font.GothamBold
    resizeIcon.TextSize           = 14
    resizeIcon.Rotation           = 90

    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and menuOpen and not isAnimating then
            resizing    = true
            resizeStart = input.Position
            startSize   = main.Size
        end
    end)
    services.UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement and menuOpen and not isAnimating then
            local d  = input.Position - resizeStart
            local nw = math.max(MIN_W, startSize.X.Offset + d.X)
            local nh = math.max(MIN_H, startSize.Y.Offset + d.Y)
            main.Size  = UDim2.new(0, nw, 0, nh)
            targetSize = main.Size
        end
    end)
    services.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
    end)

    -- ── Panel catégories (gauche) ─────────────────────────────────────────────
    local catPanel = Instance.new("Frame", main)
    catPanel.Name             = "CategoryPanel"
    catPanel.Size             = UDim2.new(0, 158, 1, -76)
    catPanel.Position         = UDim2.new(0, 10, 0, 66)
    catPanel.BackgroundColor3 = C.catPanel
    catPanel.BorderSizePixel  = 0
    mkCorner(catPanel, 10)

    local badge = Instance.new("Frame", catPanel)
    badge.Size             = UDim2.new(0, 62, 0, 20)
    badge.Position         = UDim2.new(0, 10, 0, 9)
    badge.BackgroundColor3 = C.catBadge
    badge.BorderSizePixel  = 0
    mkCorner(badge, 5)
    local badgeLbl = Instance.new("TextLabel", badge)
    badgeLbl.Size             = UDim2.new(1, 0, 1, 0)
    badgeLbl.BackgroundTransparency = 1
    badgeLbl.Text             = "TABS"
    badgeLbl.TextColor3       = C.textDim
    badgeLbl.Font             = Enum.Font.GothamBold
    badgeLbl.TextSize         = 9

    local catList = Instance.new("ScrollingFrame", catPanel)
    catList.Size               = UDim2.new(1, -8, 1, -40)
    catList.Position           = UDim2.new(0, 4, 0, 36)
    catList.BackgroundTransparency = 1
    catList.BorderSizePixel    = 0
    catList.ScrollBarThickness = 2
    catList.ScrollBarImageColor3 = C.accent
    catList.CanvasSize         = UDim2.new(0, 0, 0, 0)
    local catLayout = Instance.new("UIListLayout", catList)
    catLayout.SortOrder           = Enum.SortOrder.LayoutOrder
    catLayout.Padding             = UDim.new(0, 5)
    catLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    catLayout.FillDirection       = Enum.FillDirection.Vertical
    catLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        catList.CanvasSize = UDim2.new(0, 0, 0, catLayout.AbsoluteContentSize.Y + 8)
    end)

    -- ── Zone de contenu (droite) ──────────────────────────────────────────────
    local contentArea = Instance.new("Frame", main)
    contentArea.Position         = UDim2.new(0, 178, 0, 66)
    contentArea.Size             = UDim2.new(1, -188, 1, -76)
    contentArea.BackgroundTransparency = 1

    -- ── Création dynamique des pages & boutons depuis TAB_REGISTRY ────────────
    local tabPages = {}
    local tabBtns  = {}
    local activeTab = nil

    local function switchTab(name)
        if activeTab and tabBtns[activeTab] then
            tabBtns[activeTab].btn.BackgroundTransparency = 1
            tabBtns[activeTab].btn.TextColor3             = C.textDim
            tabBtns[activeTab].bar.Visible                = false
        end
        activeTab = name
        if tabBtns[name] then
            tabBtns[name].btn.BackgroundColor3       = C.catSelected
            tabBtns[name].btn.BackgroundTransparency = 0
            tabBtns[name].btn.TextColor3             = C.text
            tabBtns[name].bar.Visible                = true
        end
        for n, page in pairs(tabPages) do page.Visible = (n == name) end
    end

    -- Table des helpers passée aux builders
    local ui = {
        newSection              = newSection,
        newCard                 = newCard,
        newCardLabel            = newCardLabel,
        newInfoText             = newInfoText,
        newTogglePill           = newTogglePill,
        newToggleCard           = newToggleCard,
        newToggleWithSettings   = newToggleWithSettings,
        newSlider               = newSlider,
        newCollapsible          = newCollapsible,
        newColorPreviewCard     = newColorPreviewCard,
        newKeybindCard          = newKeybindCard,
        newKeybindButton        = newKeybindButton,
        mkCorner                = mkCorner,
        C                       = C,
    }

    for i, tabDef in ipairs(TAB_REGISTRY) do
        local page = newTabPage(contentArea)
        tabPages[tabDef.name]  = page
        self.tabs[tabDef.name] = page

        local btn = Instance.new("TextButton", catList)
        btn.Size                   = UDim2.new(1, -4, 0, 38)
        btn.BackgroundColor3       = C.catSelected
        btn.BackgroundTransparency = 1
        btn.BorderSizePixel        = 0
        btn.LayoutOrder            = i
        btn.Text                   = "      " .. (tabDef.icon ~= "" and tabDef.icon .. " " or "") .. tabDef.name
        btn.TextColor3             = C.textDim
        btn.Font                   = Enum.Font.GothamBold
        btn.TextSize               = 13
        btn.TextXAlignment         = Enum.TextXAlignment.Left
        btn.AutoButtonColor        = false
        mkCorner(btn, 7)

        local bar = Instance.new("Frame", btn)
        bar.Size             = UDim2.new(0, 2, 0, 16)
        bar.Position         = UDim2.new(0, 8, 0.5, -8)
        bar.BackgroundColor3 = C.text
        bar.BorderSizePixel  = 0
        bar.Visible          = false
        mkCorner(bar, 10)
        local barGrad = Instance.new("UIGradient", bar)
        barGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, C.accent),
            ColorSequenceKeypoint.new(1, C.accent:Lerp(Color3.fromRGB(0, 0, 0), 0.4)),
        })
        barGrad.Rotation = 90

        tabBtns[tabDef.name]         = {btn = btn, bar = bar}
        self.tabButtons[tabDef.name] = btn
        btn.MouseButton1Click:Connect(function() switchTab(tabDef.name) end)
    end

    -- Build le contenu de chaque onglet
    for _, tabDef in ipairs(TAB_REGISTRY) do
        if tabDef.builder then
            tabDef.builder(tabPages[tabDef.name], config, callbacks, services, ui)
        end
    end

    if #TAB_REGISTRY > 0 then
        switchTab(TAB_REGISTRY[1].name)
    end
end

-- ── Builders des onglets natifs ───────────────────────────────────────────────

function GUI:registerDefaultTabs()

    -- Keybinds par defaut
    local kbDefaults = {
        { id = "toggleGui",       label = "Toggle GUI",          key = Enum.KeyCode.Insert,  callback = function() GUI:toggleVisibility() end },
        { id = "toggleSilent",    label = "Silent",              key = Enum.KeyCode.Unknown, callback = nil },
        { id = "toggleHitbox",    label = "Show HitBox",         key = Enum.KeyCode.Unknown, callback = nil },
        { id = "toggleAim",       label = "Aim Assist",          key = Enum.KeyCode.Unknown, callback = nil },
        { id = "toggleFov",       label = "Afficher FOV",        key = Enum.KeyCode.Unknown, callback = nil },
        { id = "toggleESP",       label = "ESP",                 key = Enum.KeyCode.Unknown, callback = nil },
        { id = "toggleFullbright",label = "FullBright",          key = Enum.KeyCode.Unknown, callback = nil },
        { id = "toggleRecoil",    label = "No Recoil",           key = Enum.KeyCode.Unknown, callback = nil },
        { id = "toggleFiremode",  label = "All Firemodes",       key = Enum.KeyCode.Unknown, callback = nil },
        { id = "toggleEspHL",     label = "Highlight ESP",       key = Enum.KeyCode.Unknown, callback = nil },
    }
    for _, kb in ipairs(kbDefaults) do
        if not KEYBIND_REGISTRY[kb.id] then
            GUI:registerKeybind(kb.id, kb.label, kb.key, kb.callback)
        end
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- COMBAT
    -- ════════════════════════════════════════════════════════════════════════
    GUI:registerTab("Combat", "", function(page, config, callbacks, services, ui)
        KEYBIND_REGISTRY["toggleSilent"].callback  = function() if callbacks.onSizingToggle       then local v = not config.sizingEnabled;  config.sizingEnabled  = v; callbacks.onSizingToggle(v)       end end
        KEYBIND_REGISTRY["toggleHitbox"].callback  = function() if callbacks.onShowTargetBoxToggle then local v = not config.showTargetBox;  config.showTargetBox  = v; callbacks.onShowTargetBoxToggle(v) end end
        KEYBIND_REGISTRY["toggleAim"].callback     = function() if callbacks.onAimToggle          then local v = not config.aimEnabled;     config.aimEnabled     = v; callbacks.onAimToggle(v)          end end
        KEYBIND_REGISTRY["toggleFov"].callback     = function() if callbacks.onFovToggle          then local v = not config.fovEnabled;     config.fovEnabled     = v; callbacks.onFovToggle(v)          end end

        ui.newSection(page, "COMBAT")

        -- Silent (pas de settings)
        ui.newToggleCard(page, "Silent", config.sizingEnabled, callbacks.onSizingToggle, "toggleSilent", services)

        -- Show HitBox + ⚙ ouvre les settings hitbox
        ui.newToggleWithSettings(page, "Show HitBox", config.showTargetBox, callbacks.onShowTargetBoxToggle, "toggleHitbox", services, function(add)
            local previewCard, boxPreview = ui.newColorPreviewCard(nil, "Aperçu couleur Hitbox", config.TARGET_BOX_COLOR)
            add(previewCard)
            local initialSize = math.floor(config.TARGET_BOX_SIZE.X)
            add(ui.newSlider, "Hitbox Taille", initialSize, 20, function(v)
                if callbacks.onTargetBoxSizeChange then callbacks.onTargetBoxSizeChange(v)
                elseif config.updateTargetBoxSize  then config:updateTargetBoxSize(v) end
            end, services)
            add(ui.newSlider, "Hitbox R", config.TARGET_BOX_COLOR_R, 255, function(v)
                if config.updateTargetBoxR     then config:updateTargetBoxR(v) end
                if config.updateTargetBoxColor then config:updateTargetBoxColor(config.TARGET_BOX_COLOR_R, config.TARGET_BOX_COLOR_G, config.TARGET_BOX_COLOR_B) end
                if callbacks.onTargetBoxColorChange then callbacks.onTargetBoxColorChange(config.TARGET_BOX_COLOR_R, config.TARGET_BOX_COLOR_G, config.TARGET_BOX_COLOR_B) end
                boxPreview.BackgroundColor3 = Color3.fromRGB(config.TARGET_BOX_COLOR_R, config.TARGET_BOX_COLOR_G, config.TARGET_BOX_COLOR_B)
                if callbacks.onShowTargetBoxToggle then callbacks.onShowTargetBoxToggle(config.showTargetBox) end
            end, services)
            add(ui.newSlider, "Hitbox G", config.TARGET_BOX_COLOR_G, 255, function(v)
                if config.updateTargetBoxG     then config:updateTargetBoxG(v) end
                if config.updateTargetBoxColor then config:updateTargetBoxColor(config.TARGET_BOX_COLOR_R, config.TARGET_BOX_COLOR_G, config.TARGET_BOX_COLOR_B) end
                if callbacks.onTargetBoxColorChange then callbacks.onTargetBoxColorChange(config.TARGET_BOX_COLOR_R, config.TARGET_BOX_COLOR_G, config.TARGET_BOX_COLOR_B) end
                boxPreview.BackgroundColor3 = Color3.fromRGB(config.TARGET_BOX_COLOR_R, config.TARGET_BOX_COLOR_G, config.TARGET_BOX_COLOR_B)
                if callbacks.onShowTargetBoxToggle then callbacks.onShowTargetBoxToggle(config.showTargetBox) end
            end, services)
            add(ui.newSlider, "Hitbox B", config.TARGET_BOX_COLOR_B, 255, function(v)
                if config.updateTargetBoxB     then config:updateTargetBoxB(v) end
                if config.updateTargetBoxColor then config:updateTargetBoxColor(config.TARGET_BOX_COLOR_R, config.TARGET_BOX_COLOR_G, config.TARGET_BOX_COLOR_B) end
                if callbacks.onTargetBoxColorChange then callbacks.onTargetBoxColorChange(config.TARGET_BOX_COLOR_R, config.TARGET_BOX_COLOR_G, config.TARGET_BOX_COLOR_B) end
                boxPreview.BackgroundColor3 = Color3.fromRGB(config.TARGET_BOX_COLOR_R, config.TARGET_BOX_COLOR_G, config.TARGET_BOX_COLOR_B)
                if callbacks.onShowTargetBoxToggle then callbacks.onShowTargetBoxToggle(config.showTargetBox) end
            end, services)
            add(ui.newSlider, "Hitbox Transparence (%)", math.floor(config.TARGET_BOX_TRANSPARENCY * 100), 100, function(v)
                local f = v / 100
                if config.updateTargetBoxTransparency then config.updateTargetBoxTransparency(config, f)
                else config.TARGET_BOX_TRANSPARENCY = f end
                if callbacks.onTargetBoxTransparencyChange then callbacks.onTargetBoxTransparencyChange(f) end
            end, services)
        end)

        ui.newSection(page, "AIM ASSIST", Color3.fromRGB(255, 160, 30))

        -- Aim Assist + ⚙ ouvre FOV Radius + Smoothing
        ui.newToggleWithSettings(page, "Aim Assist (Clic Droit)", config.aimEnabled, callbacks.onAimToggle, "toggleAim", services, function(add)
            add(ui.newSlider, "FOV Radius", config.fovRadius, 400, callbacks.onFovRadiusChange, services)
            add(ui.newSlider, "Smoothing",  config.smoothing,  99,  callbacks.onSmoothingChange,  services)
            add(ui.newInfoText, "Maintenir clic droit pour activer l'aim.")
        end)

        -- Afficher FOV (pas de settings spécifiques)
        ui.newToggleCard(page, "Afficher FOV", config.fovEnabled, callbacks.onFovToggle, "toggleFov", services)
    end, 1)

    -- ════════════════════════════════════════════════════════════════════════
    -- VISUALS
    -- ════════════════════════════════════════════════════════════════════════
    GUI:registerTab("Visuals", "", function(page, config, callbacks, services, ui)
        KEYBIND_REGISTRY["toggleESP"].callback        = function() if callbacks.onHighlightsToggle then local v = not config.highlightEnabled;  config.highlightEnabled  = v; callbacks.onHighlightsToggle(v) end end
        KEYBIND_REGISTRY["toggleFullbright"].callback = function() if callbacks.onFullBrightToggle then local v = not config.fullBrightEnabled; config.fullBrightEnabled = v; callbacks.onFullBrightToggle(v) end end

        ui.newSection(page, "VISUALS")
        ui.newToggleCard(page, "ESP",       config.highlightEnabled,  callbacks.onHighlightsToggle, "toggleESP",        services)
        ui.newToggleCard(page, "FullBright", config.fullBrightEnabled, callbacks.onFullBrightToggle, "toggleFullbright", services)
        local addV = ui.newCollapsible(page, "⚙  NPC Settings", true)
        addV(ui.newSlider, "NPC Range", config.npcDetectionRadius, config.MAX_NPC_DETECTION_RADIUS, callbacks.onNPCDetectionRadiusChange, services)
        addV(ui.newInfoText, "Si vous avez des problèmes de performance, diminuez la portée NPC puis remontez-la progressivement.")
    end, 2)

    -- ════════════════════════════════════════════════════════════════════════
    -- WEAPONS
    -- ════════════════════════════════════════════════════════════════════════
    GUI:registerTab("Weapons", "", function(page, config, callbacks, services, ui)
        KEYBIND_REGISTRY["toggleRecoil"].callback   = function() if callbacks.onStabilityToggle         then local v = not config.patchOptions.recoil;     config.patchOptions.recoil     = v; callbacks.onStabilityToggle(v)         end end
        KEYBIND_REGISTRY["toggleFiremode"].callback = function() if callbacks.onFiremodeOptionsToggle   then local v = not config.patchOptions.firemodes;   config.patchOptions.firemodes   = v; callbacks.onFiremodeOptionsToggle(v)  end end

        ui.newSection(page, "WEAPONS")
        ui.newInfoText(page, "⚠  Réinitialisez votre personnage pour appliquer les changements.")
        local addW = ui.newCollapsible(page, "⚙  Options Armes", true)
        addW(ui.newToggleCard, "No Recoil",     config.patchOptions.recoil,    callbacks.onStabilityToggle,       "toggleRecoil",   services)
        addW(ui.newToggleCard, "All Firemodes",  config.patchOptions.firemodes, callbacks.onFiremodeOptionsToggle, "toggleFiremode", services)
    end, 3)

    -- ════════════════════════════════════════════════════════════════════════
    -- COLORS
    -- ════════════════════════════════════════════════════════════════════════
    GUI:registerTab("Colors", "", function(page, config, callbacks, services, ui)

        -- ── Visible Color ────────────────────────────────────────────────────
        local addVC = ui.newCollapsible(page, "VISIBLE COLOR", true, Color3.fromRGB(80, 220, 120))
        local visCard, visPreview = ui.newColorPreviewCard(nil, "Aperçu couleur", config.visibleColor)
        addVC(visCard)
        addVC(ui.newSlider, "R", config.visibleR, 255, function(v)
            callbacks.onVisibleRChange(v)
            visPreview.BackgroundColor3 = Color3.fromRGB(v, config.visibleG, config.visibleB)
        end, services)
        addVC(ui.newSlider, "G", config.visibleG, 255, function(v)
            callbacks.onVisibleGChange(v)
            visPreview.BackgroundColor3 = Color3.fromRGB(config.visibleR, v, config.visibleB)
        end, services)
        addVC(ui.newSlider, "B", config.visibleB, 255, function(v)
            callbacks.onVisibleBChange(v)
            visPreview.BackgroundColor3 = Color3.fromRGB(config.visibleR, config.visibleG, v)
        end, services)

        -- ── Hidden Color ─────────────────────────────────────────────────────
        local addHC = ui.newCollapsible(page, "HIDDEN COLOR", true, Color3.fromRGB(220, 80, 80))
        local hidCard, hidPreview = ui.newColorPreviewCard(nil, "Aperçu couleur", config.hiddenColor)
        addHC(hidCard)
        addHC(ui.newSlider, "R", config.hiddenR, 255, function(v)
            callbacks.onHiddenRChange(v)
            hidPreview.BackgroundColor3 = Color3.fromRGB(v, config.hiddenG, config.hiddenB)
        end, services)
        addHC(ui.newSlider, "G", config.hiddenG, 255, function(v)
            callbacks.onHiddenGChange(v)
            hidPreview.BackgroundColor3 = Color3.fromRGB(config.hiddenR, v, config.hiddenB)
        end, services)
        addHC(ui.newSlider, "B", config.hiddenB, 255, function(v)
            callbacks.onHiddenBChange(v)
            hidPreview.BackgroundColor3 = Color3.fromRGB(config.hiddenR, config.hiddenG, v)
        end, services)
    end, 4)

    -- ════════════════════════════════════════════════════════════════════════
    -- ESP
    -- ════════════════════════════════════════════════════════════════════════
    GUI:registerTab("ESP", "", function(page, config, callbacks, services, ui)
        KEYBIND_REGISTRY["toggleEspHL"].callback = function() if callbacks.onHighlightESPToggle then local v = not config.espHighlightEnabled; config.espHighlightEnabled = v; callbacks.onHighlightESPToggle(v) end end

        ui.newSection(page, "HIGHLIGHT ESP")
        ui.newToggleCard(page, "Highlight ESP", config.espHighlightEnabled, callbacks.onHighlightESPToggle, "toggleEspHL", services)
        ui.newInfoText(page, "Affiche un contour coloré sur chaque NPC, visible à travers les murs.")

        -- ── Fill Color ───────────────────────────────────────────────────────
        local addFill = ui.newCollapsible(page, "FILL COLOR", true, Color3.fromRGB(255, 100, 50))
        local fillCard, espFillPreview = ui.newColorPreviewCard(nil, "Aperçu Fill", config.espFillColor or Color3.fromRGB(255, 0, 0))
        addFill(fillCard)
        addFill(ui.newSlider, "Fill R", config.espFillR, 255, function(v)
            callbacks.onEspFillRChange(v)
            espFillPreview.BackgroundColor3 = Color3.fromRGB(v, config.espFillG, config.espFillB)
        end, services)
        addFill(ui.newSlider, "Fill G", config.espFillG, 255, function(v)
            callbacks.onEspFillGChange(v)
            espFillPreview.BackgroundColor3 = Color3.fromRGB(config.espFillR, v, config.espFillB)
        end, services)
        addFill(ui.newSlider, "Fill B", config.espFillB, 255, function(v)
            callbacks.onEspFillBChange(v)
            espFillPreview.BackgroundColor3 = Color3.fromRGB(config.espFillR, config.espFillG, v)
        end, services)
        addFill(ui.newSlider, "Fill Transparence (%)", math.floor((config.espFillTransparency or 0.5) * 100), 100, function(v)
            callbacks.onEspFillTransparencyChange(v)
        end, services)

        -- ── Outline Color ────────────────────────────────────────────────────
        local addOut = ui.newCollapsible(page, "OUTLINE COLOR", true, Color3.fromRGB(100, 180, 255))
        local outCard, espOutlinePreview = ui.newColorPreviewCard(nil, "Aperçu Outline", config.espOutlineColor or Color3.fromRGB(255, 255, 255))
        addOut(outCard)
        addOut(ui.newSlider, "Outline R", config.espOutlineR, 255, function(v)
            callbacks.onEspOutlineRChange(v)
            espOutlinePreview.BackgroundColor3 = Color3.fromRGB(v, config.espOutlineG, config.espOutlineB)
        end, services)
        addOut(ui.newSlider, "Outline G", config.espOutlineG, 255, function(v)
            callbacks.onEspOutlineGChange(v)
            espOutlinePreview.BackgroundColor3 = Color3.fromRGB(config.espOutlineR, v, config.espOutlineB)
        end, services)
        addOut(ui.newSlider, "Outline B", config.espOutlineB, 255, function(v)
            callbacks.onEspOutlineBChange(v)
            espOutlinePreview.BackgroundColor3 = Color3.fromRGB(config.espOutlineR, config.espOutlineG, v)
        end, services)
        addOut(ui.newSlider, "Outline Transparence (%)", math.floor((config.espOutlineTransparency or 0) * 100), 100, function(v)
            callbacks.onEspOutlineTransparencyChange(v)
        end, services)
    end, 5)

    -- ════════════════════════════════════════════════════════════════════════
    -- KEYBINDS
    -- ════════════════════════════════════════════════════════════════════════
    GUI:registerTab("Keybinds", "", function(page, config, callbacks, services, ui)
        ui.newSection(page, "KEYBINDS", ui.C.accent)
        ui.newInfoText(page, "Cliquez sur [ ] pour réassigner une touche, puis appuyez sur la nouvelle touche.")
        local addKB = ui.newCollapsible(page, "⚙  Raccourcis clavier", true)
        for id, kb in pairs(KEYBIND_REGISTRY) do
            addKB(ui.newKeybindCard, kb.label, id, services)
        end
    end, 6)

    -- ════════════════════════════════════════════════════════════════════════
    -- CREDITS
    -- ════════════════════════════════════════════════════════════════════════
    GUI:registerTab("Credits", "", function(page, config, callbacks, services, ui)
        ui.newSection(page, "CREDITS & LIENS")

        local clipStatus = ui.newInfoText(page, "Clique sur un bouton pour copier le lien.")
        clipStatus.TextColor3 = Color3.fromRGB(140, 200, 255)

        local function copyLink(url, label)
            if type(setclipboard) == "function" then
                local ok = pcall(setclipboard, url)
                if ok then clipStatus.Text = "✓  Copié : " .. label; return end
            end
            clipStatus.Text = "Presse-papiers non disponible dans cet exécuteur."
        end

        local authorCard = ui.newCard(page, 48)
        local aName = ui.newCardLabel(authorCard, "FXTHai", ui.C.text)
        aName.Font  = Enum.Font.GothamBold
        local aSub  = Instance.new("TextLabel", authorCard)
        aSub.Size             = UDim2.new(1, -110, 0, 14)
        aSub.Position         = UDim2.new(0, 14, 1, -18)
        aSub.BackgroundTransparency = 1
        aSub.Text             = "Auteur du script"
        aSub.TextColor3       = ui.C.textDim
        aSub.Font             = Enum.Font.Gotham
        aSub.TextSize         = 10
        aSub.TextXAlignment   = Enum.TextXAlignment.Left

        local function newLinkCard(label, url, color)
            local card = ui.newCard(page, 48)
            ui.newCardLabel(card, label)

            local urlLbl = Instance.new("TextLabel", card)
            urlLbl.Size             = UDim2.new(1, -110, 0, 12)
            urlLbl.Position         = UDim2.new(0, 14, 1, -16)
            urlLbl.BackgroundTransparency = 1
            urlLbl.Text             = url
            urlLbl.TextColor3       = ui.C.textDim
            urlLbl.Font             = Enum.Font.Gotham
            urlLbl.TextSize         = 9
            urlLbl.TextXAlignment   = Enum.TextXAlignment.Left
            urlLbl.TextTruncate     = Enum.TextTruncate.AtEnd

            local pill = Instance.new("TextButton", card)
            pill.Size             = UDim2.new(0, 78, 0, 28)
            pill.Position         = UDim2.new(1, -88, 0.5, -14)
            pill.BackgroundColor3 = color or ui.C.btnOn
            pill.Text             = "COPY"
            pill.TextColor3       = ui.C.text
            pill.Font             = Enum.Font.GothamBold
            pill.TextSize         = 12
            pill.AutoButtonColor  = false
            pill.BorderSizePixel  = 0
            ui.mkCorner(pill, 6)
            pill.MouseButton1Click:Connect(function() copyLink(url, label) end)
        end

        newLinkCard("GitHub", "soon", Color3.fromRGB(45, 95, 160))
        newLinkCard("Reddit", "soon", Color3.fromRGB(185, 75, 45))
        ui.newInfoText(page, "Badge en haut à droite pour afficher / masquer le menu.")
    end, 7)

end

-- ── Visibilité (animation TweenService) ──────────────────────────────────────

function GUI:setVisibleState(isVisible, tweenService)
    if not self.mainFrame then return isVisible end
    local TS = tweenService or game:GetService("TweenService")
    if isAnimating then return menuOpen end
    isAnimating = true

    if not isVisible then
        savedPosition = self.mainFrame.Position
        local tween = TS:Create(self.mainFrame,
            TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            { Size = UDim2.new(0, 0, 0, 0),
              Position = UDim2.new(savedPosition.X.Scale, savedPosition.X.Offset,
                                   savedPosition.Y.Scale, savedPosition.Y.Offset) })
        tween:Play()
        tween.Completed:Connect(function()
            self.mainFrame.Visible = false
            if self.modalOverlay    then self.modalOverlay.Visible   = false end
            if self.cursorIndicator then self.cursorIndicator.Visible = false end
            menuOpen    = false
            isAnimating = false
        end)
    else
        self.mainFrame.Visible = true
        if self.modalOverlay    then self.modalOverlay.Visible   = true end
        if self.cursorIndicator then self.cursorIndicator.Visible = true end
        self.mainFrame.Size     = UDim2.new(0, 0, 0, 0)
        self.mainFrame.Position = savedPosition or UDim2.new(0.5, -320, 0.5, -215)
        local tween = TS:Create(self.mainFrame,
            TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Size     = targetSize,
              Position = savedPosition or UDim2.new(0.5, -320, 0.5, -215) })
        tween:Play()
        tween.Completed:Connect(function()
            menuOpen    = true
            isAnimating = false
        end)
    end

    updateFloatBtnText(self.toggleButton, isVisible)
    return isVisible
end

function GUI:toggleVisibility(tweenService)
    if self.mainFrame then return self:setVisibleState(not menuOpen, tweenService) end
    return false
end

-- ── Destruction ───────────────────────────────────────────────────────────────

function GUI:destroy()
    if self.screenGui then self.screenGui:Destroy() end
    self.screenGui       = nil
    self.mainFrame       = nil
    self.modalOverlay    = nil
    self.cursorIndicator = nil
    self.toggleButton    = nil
    self.tabButtons      = {}
    self.tabs            = {}
    -- Note : TAB_REGISTRY et KEYBIND_REGISTRY sont intentionnellement conservés
    -- pour permettre un re-init sans devoir rappeler registerDefaultTabs().
    -- Appelez GUI:clearRegistries() si vous voulez tout repartir de zéro.
end

function GUI:clearRegistries()
    TAB_REGISTRY     = {}
    KEYBIND_REGISTRY = {}
end

-- ── Exemple d'usage dans main.lua ────────────────────────────────────────────
--
--   local GUI = require(path.to.gui)
--
--   -- Keybinds (optionnel, avant registerDefaultTabs)
--   GUI:registerKeybind("toggleGui",  "Toggle GUI",        Enum.KeyCode.Insert, function() GUI:toggleVisibility() end)
--   GUI:registerKeybind("toggleAim",  "Toggle Aim Assist", Enum.KeyCode.X,      function() callbacks.onAimToggle(not config.aimEnabled) end)
--
--   -- Onglet custom (optionnel)
--   GUI:registerTab("MonOnglet", "", function(page, config, callbacks, services, ui)
--       ui.newSection(page, "MON ONGLET")
--       ui.newToggleCard(page, "Ma Feature", false, function(v) end)
--   end, 2)
--
--   GUI:registerDefaultTabs()
--   GUI:init(services, config, callbacks)

return GUI
