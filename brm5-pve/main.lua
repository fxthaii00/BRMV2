-- BRM5 v7.0 by dexter (Modified with Drag, Save Positions & Custom Keybind)
-- Credits to ryknuq and their overvoltage script, which helped me understand how to integrate the Aim into my script. Without their script, I don't think I could have done this.
-- Coordinates all modules

if typeof(clear) == "function" then
    clear()
end

local MAIN_VERSION = "cache-bust-2026-03-18-01"
local GITHUB_BASE = "https://raw.githubusercontent.com/fxthaii00/BRM5/main/brm5-pve/modules/"
local CACHE_BUSTER = MAIN_VERSION .. "-" .. tostring(os.time())

local function loadModule(moduleName)
    local url = GITHUB_BASE .. moduleName .. ".lua?v=" .. CACHE_BUSTER

    local okResponse, response = pcall(function()
        return game:HttpGet(url)
    end)
    if not okResponse then
        warn("Failed to download module: " .. moduleName)
        warn("URL: " .. url)
        warn("HttpGet error: " .. tostring(response))
        return nil
    end

    if type(response) ~= "string" or response == "" then
        warn("Module download returned empty content: " .. moduleName)
        warn("URL: " .. url)
        return nil
    end

    local chunk, compileError = loadstring(response)
    if not chunk then
        warn("Failed to compile module: " .. moduleName)
        warn("URL: " .. url)
        warn("Compile error: " .. tostring(compileError))
        return nil
    end

    local okRun, result = pcall(chunk)
    if not okRun then
        warn("Failed to execute module: " .. moduleName)
        warn("URL: " .. url)
        warn("Runtime error: " .. tostring(result))
        return nil
    end

    return result
end

local Services = loadModule("services")
local Config = loadModule("config")
local NPCManager = loadModule("npc_manager")
local TargetSizing = loadModule("silent")
local Markers = loadModule("walls")
local Lighting = loadModule("fullbright")
local Weapons = loadModule("norecoil")
local GUI = loadModule("gui")
local HighlightESP = loadModule("highlight")
local Aim = loadModule("aim")

if not (Services and Config and NPCManager and TargetSizing and Markers and Lighting and Weapons and GUI and HighlightESP and Aim) then
    error("Failed to load one or more modules. Please verify the remote module files.")
end

-- Extendre la sérialisation pour inclure la position de l'UI, du bouton et du Keybind
local originalSerialize = Config.serialize
function Config:serialize()
    local tbl = originalSerialize(self)
    tbl.currentToggleKey = self.currentToggleKey or "Home"
    if self.savedGuiPos then
        tbl.savedGuiPos = {X = self.savedGuiPos.X.Offset, Y = self.savedGuiPos.Y.Offset}
    end
    if self.savedBtnPos then
        tbl.savedBtnPos = {X = self.savedBtnPos.X.Offset, Y = self.savedBtnPos.Y.Offset}
    end
    return tbl
end

local originalApply = Config.applySavedData
function Config:applySavedData(data)
    originalApply(self, data)
    if data then
        self.currentToggleKey = data.currentToggleKey or "Home"
        if data.savedGuiPos then
            self.savedGuiPos = UDim2.new(0.5, data.savedGuiPos.X, 0.5, data.savedGuiPos.Y)
        end
        if data.savedBtnPos then
            self.savedBtnPos = UDim2.new(0, data.savedBtnPos.X, 0.5, data.savedBtnPos.Y)
        end
    end
end

Config:load()
Config._npcManager = NPCManager  -- permet à aim.lua de scanner les NPCs même sans ESP activé
Lighting:storeOriginalSettings(Services.Lighting)

local runtimeConnections = {}

local function saveConfig()
    Config:save()
end

local function syncMouseState()
    if Config.guiVisible then
        Services.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        Services.UserInputService.MouseIconEnabled = true
    end
end

local function forceMouseLock()
    Services.UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    Services.UserInputService.MouseIconEnabled = false
end

local function toggleGUIVisibility()
    local wasVisible = Config.guiVisible
    Config.guiVisible = GUI:toggleVisibility()
    if Config.guiVisible then
        syncMouseState()
    elseif wasVisible then
        forceMouseLock()
    end
    return Config.guiVisible
end

local function disconnectRuntimeConnections()
    for _, connection in ipairs(runtimeConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    runtimeConnections = {}
end

-- Variables pour l'état du Keybind interactif
local isBinding = false

local callbacks = {
    onSizingToggle = function(enabled)
        Config.sizingEnabled = enabled
        if not enabled then
            TargetSizing:cleanup(NPCManager)
        end
        NPCManager:refreshTrackedNPCs(Services.Workspace, Markers, TargetSizing, Config)
        saveConfig()
    end,

    onShowTargetBoxToggle = function(enabled)
        Config.showTargetBox = enabled
        NPCManager:refreshTrackedNPCs(Services.Workspace, Markers, TargetSizing, Config)
        saveConfig()
    end,

    onHighlightsToggle = function(enabled)
        Config.highlightEnabled = enabled
        NPCManager:refreshTrackedNPCs(Services.Workspace, Markers, TargetSizing, Config)
        if enabled then
            Markers.enable(NPCManager, Config)
        else
            Markers.disable()
        end
        saveConfig()
    end,

    onFullBrightToggle = function(enabled)
        Config.fullBrightEnabled = enabled
        if not enabled then
            Lighting:restoreOriginal(Services.Lighting)
        end
        saveConfig()
    end,

    onStabilityToggle = function(enabled)
        Config.patchOptions.recoil = enabled
        Weapons.patchWeapons(Services.ReplicatedStorage, Config.patchOptions)
        saveConfig()
    end,

    onFiremodeOptionsToggle = function(enabled)
        Config.patchOptions.firemodes = enabled
        Weapons.patchWeapons(Services.ReplicatedStorage, Config.patchOptions)
        saveConfig()
    end,

    onVisibleRChange = function(value)
        Config:updateVisibleColor(value, nil, nil)
        saveConfig()
    end,

    onVisibleGChange = function(value)
        Config:updateVisibleColor(nil, value, nil)
        saveConfig()
    end,

    onVisibleBChange = function(value)
        Config:updateVisibleColor(nil, nil, value)
        saveConfig()
    end,

    onHiddenRChange = function(value)
        Config:updateHiddenColor(value, nil, nil)
        saveConfig()
    end,

    onHiddenGChange = function(value)
        Config:updateHiddenColor(nil, value, nil)
        saveConfig()
    end,

    onHiddenBChange = function(value)
        Config:updateHiddenColor(nil, nil, value)
        saveConfig()
    end,

    onNPCDetectionRadiusChange = function(value)
        Config:updateNPCDetectionRadius(value)
        NPCManager:refreshTrackedNPCs(Services.Workspace, Markers, TargetSizing, Config)
        saveConfig()
    end,

    onVisibilityToggle = function()
        toggleGUIVisibility()
    end,

    onHighlightESPToggle = function(enabled)
        Config.espHighlightEnabled = enabled
        if enabled then
            HighlightESP.enable(NPCManager, Config)
        else
            HighlightESP.disable()
        end
        saveConfig()
    end,

    onEspFillRChange = function(v)
        Config:updateEspFillColor(v, nil, nil)
        HighlightESP.updateAll(NPCManager, Config)
        saveConfig()
    end,
    onEspFillGChange = function(v)
        Config:updateEspFillColor(nil, v, nil)
        HighlightESP.updateAll(NPCManager, Config)
        saveConfig()
    end,
    onEspFillBChange = function(v)
        Config:updateEspFillColor(nil, nil, v)
        HighlightESP.updateAll(NPCManager, Config)
        saveConfig()
    end,
    onEspFillTransparencyChange = function(v)
        Config.espFillTransparency = v / 100
        HighlightESP.updateAll(NPCManager, Config)
        saveConfig()
    end,

    onEspOutlineRChange = function(v)
        Config:updateEspOutlineColor(v, nil, nil)
        HighlightESP.updateAll(NPCManager, Config)
        saveConfig()
    end,
    onEspOutlineGChange = function(v)
        Config:updateEspOutlineColor(nil, v, nil)
        HighlightESP.updateAll(NPCManager, Config)
        saveConfig()
    end,
    onEspOutlineBChange = function(v)
        Config:updateEspOutlineColor(nil, nil, v)
        HighlightESP.updateAll(NPCManager, Config)
        saveConfig()
    end,
    onEspOutlineTransparencyChange = function(v)
        Config.espOutlineTransparency = v / 100
        HighlightESP.updateAll(NPCManager, Config)
        saveConfig()
    end,

    onAimToggle = function(enabled)
        Config.aimEnabled = enabled
        if not enabled then
            Aim:cleanup()
        end
        saveConfig()
    end,

    onFovToggle = function(enabled)
        Config.fovEnabled = enabled
        saveConfig()
    end,

    onFovRadiusChange = function(value)
        Config.fovRadius = value
        saveConfig()
    end,

    onSmoothingChange = function(value)
        Config.smoothing = value
        saveConfig()
    end,

    onUnload = function()
        if Config.isUnloaded then
            return
        end

        Config.isUnloaded = true
        disconnectRuntimeConnections()
        Markers.disable()
        HighlightESP.disable()
        Aim:cleanup()
        TargetSizing:cleanup(NPCManager)
        NPCManager:cleanup()
        Lighting:restoreOriginal(Services.Lighting)
        Config.guiVisible = false
        saveConfig()
        forceMouseLock()
        GUI:destroy()
    end
}

GUI:init(Services, Config, callbacks)
syncMouseState()

-- ── INJECTION DES MODIFICATIONS POST-INIT (Positions & Keybind) ──

local keyBadge = GUI.mainFrame and GUI.mainFrame:FindFirstChild("Header") and GUI.mainFrame.Header:FindFirstChild("TextButton")
local floatBtn = GUI.toggleButton

-- Restaurer la position de la GUI si sauvegardée
if Config.savedGuiPos and GUI.mainFrame then
    GUI.mainFrame.Position = Config.savedGuiPos
end

-- Restaurer la position du bouton flottant si sauvegardée
if Config.savedBtnPos and floatBtn then
    floatBtn.Position = Config.savedBtnPos
end

-- Configurer le comportement de changement de touche (Keybind)
if keyBadge then
    keyBadge.Text = (Config.currentToggleKey or "Home"):upper()
    
    -- On déconnecte l'ancienne fonction de fermeture directe
    keyBadge:Destroy() -- On le recréé proprement pour enlever les anciennes connexions cachées
    
    local newKeyBadge = Instance.new("TextButton", GUI.mainFrame.Header)
    newKeyBadge.Size             = UDim2.new(0, 80, 0, 28)
    newKeyBadge.Position         = UDim2.new(1, -135, 0.5, -14)
    newKeyBadge.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    newKeyBadge.BorderSizePixel  = 0
    newKeyBadge.Text             = (Config.currentToggleKey or "Home"):upper()
    newKeyBadge.TextColor3       = Color3.fromRGB(230, 230, 230)
    newKeyBadge.Font             = Enum.Font.GothamBold
    newKeyBadge.TextSize         = 11
    newKeyBadge.AutoButtonColor  = false
    
    local corner = Instance.new("UICorner", newKeyBadge)
    corner.CornerRadius = UDim.new(0, 6)

    newKeyBadge.MouseButton1Click:Connect(function()
        if not isBinding then
            isBinding = true
            newKeyBadge.Text = "..."
            newKeyBadge.TextColor3 = Color3.fromRGB(140, 60, 255)
        end
    end)
    
    -- Rendre accessible globalement pour mise à jour visuelle lors de l'écoute du clavier
    keyBadge = newKeyBadge
end

-- Ajouter le système de Drag & Drop sur le bouton flottant (Open/Hide GUI)
if floatBtn then
    local draggingBtn, btnDragInput, btnDragStart, btnStartPos
    
    floatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingBtn = true
            btnDragStart = input.Position
            btnStartPos = floatBtn.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingBtn = false
                    Config.savedBtnPos = floatBtn.Position
                    saveConfig()
                end
            end)
        end
    end)
    
    floatBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            btnDragInput = input
        end
    end)
    
    table.insert(runtimeConnections, Services.RunService.Heartbeat:Connect(function()
        if draggingBtn and btnDragInput then
            local delta = btnDragInput.Position - btnDragStart
            floatBtn.Position = UDim2.new(
                btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X,
                btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y
            )
        end
    end))
end

-- Hook sur le déplacement de la fenêtre principale pour enregistrer sa position lors du relâchement
if GUI.mainFrame and GUI.mainFrame:FindFirstChild("Header") then
    GUI.mainFrame.Header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Config.savedGuiPos = GUI.mainFrame.Position
            saveConfig()
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────

NPCManager:scanWorkspace(Services.Workspace, Markers, Config)
NPCManager:setupListener(Services.Workspace, Markers, Config)
if Config.highlightEnabled then
    Markers.enable(NPCManager, Config)
end
if Config.espHighlightEnabled then
    HighlightESP.enable(NPCManager, Config)
end
if Config.patchOptions.recoil or Config.patchOptions.firemodes then
    Weapons.patchWeapons(Services.ReplicatedStorage, Config.patchOptions)
end

local markerAccumulator = 0
local targetAccumulator = 0
local npcAccumulator = 0

table.insert(runtimeConnections, Services.RunService.Heartbeat:Connect(function(dt)
    if Config.isUnloaded then
        return
    end

    if Config.guiVisible then
        syncMouseState()
    end
    Lighting:update(Services.Lighting, Config)

    npcAccumulator = npcAccumulator + dt
    if npcAccumulator >= Config.NPC_REFRESH_INTERVAL then
        NPCManager:refreshTrackedNPCs(Services.Workspace, Markers, TargetSizing, Config)
        HighlightESP.sync(NPCManager, Config)
        npcAccumulator = 0
    end

    markerAccumulator = markerAccumulator + dt
    if markerAccumulator >= Config.RAYCAST_COOLDOWN then
        local okMarkers, markerError = pcall(
            Markers.updateColors,
            NPCManager,
            Services.Workspace.CurrentCamera or Services.camera,
            Services.Workspace,
            Services.localPlayer,
            Config
        )
        if not okMarkers then
            warn("Markers.updateColors failed: " .. tostring(markerError))
        end
        markerAccumulator = 0
    end

    targetAccumulator = targetAccumulator + dt
    if targetAccumulator >= Config.TARGET_SYNC_INTERVAL then
        TargetSizing:updateAllTargets(NPCManager, Config)
        targetAccumulator = 0
    end

    -- Aim : mise à jour du cercle FOV + visée
    if Config.aimEnabled then
        Aim:updateFOVCircle(Services.Workspace.CurrentCamera or Services.camera, Config)
        if Aim.holdingRightClick then
            local target = Aim:getClosestValidHead(Markers, Services.Workspace.CurrentCamera or Services.camera, Config)
            if target then
                Aim:aimAtTarget(target, Services.Workspace.CurrentCamera or Services.camera, Config)
            end
        end
    elseif Aim.fovCircle then
        Aim:cleanup()
    end
end))

table.insert(runtimeConnections, Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if Config.isUnloaded then return end
    if Config.aimEnabled and input.UserInputType == Enum.UserInputType.MouseButton2 then
        Aim:setHoldingRightClick(true)
    end

    -- Gestion du mode édition de touche (Keybind)
    if isBinding then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local pressedKey = input.KeyCode.Name
            Config.currentToggleKey = pressedKey
            isBinding = false
            if keyBadge then
                keyBadge.Text = pressedKey:upper()
                keyBadge.TextColor3 = Color3.fromRGB(230, 230, 230)
            end
            saveConfig()
        end
        return
    end

    -- Vérification dynamique de la touche configurée (par défaut Home)
    local targetKeyName = Config.currentToggleKey or "Home"
    if not gameProcessed and input.KeyCode == Enum.KeyCode[targetKeyName] then
        toggleGUIVisibility()
    end
end))

table.insert(runtimeConnections, Services.UserInputService.InputEnded:Connect(function(input)
    if Config.isUnloaded then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Aim:setHoldingRightClick(false)
    end
end))
