-- Highlight ESP Module
-- Applique un Highlight Roblox natif sur le modèle entier de chaque NPC tracké
-- Tourne en parallèle du système box (walls.lua) sans le modifier

local HighlightESP = {}

HighlightESP.enabled       = false
HighlightESP.trackedModels = {} -- { [model] = Highlight }

-- ── Interne ────────────────────────────────────────────────────────────────

local function applyConfig(h, config)
    h.FillColor           = config.espFillColor           or Color3.fromRGB(255, 0, 0)
    h.FillTransparency    = config.espFillTransparency    ~= nil and config.espFillTransparency    or 0.5
    h.OutlineColor        = config.espOutlineColor        or Color3.fromRGB(255, 255, 255)
    h.OutlineTransparency = config.espOutlineTransparency ~= nil and config.espOutlineTransparency or 0
end

local function ensureHighlight(model, config)
    -- Nettoie si le Highlight existant est mort
    local existing = HighlightESP.trackedModels[model]
    if existing and existing.Parent then
        applyConfig(existing, config)
        return existing
    end

    -- Supprime tout Highlight résiduel non géré
    local old = model:FindFirstChild("ESP_Highlight")
    if old then pcall(function() old:Destroy() end) end

    local h = Instance.new("Highlight")
    h.Name      = "ESP_Highlight"
    h.Adornee   = model
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    applyConfig(h, config)
    h.Parent = model

    HighlightESP.trackedModels[model] = h
    return h
end

local function removeHighlight(model)
    local h = HighlightESP.trackedModels[model]
    if h then pcall(function() h:Destroy() end) end
    HighlightESP.trackedModels[model] = nil
    -- Sécurité : orphelins
    if model and model.Parent then
        local old = model:FindFirstChild("ESP_Highlight")
        if old then pcall(function() old:Destroy() end) end
    end
end

-- ── API publique ────────────────────────────────────────────────────────────

function HighlightESP.enable(npcManager, config)
    HighlightESP.enabled = true
    for model, _ in pairs(npcManager:getActiveNPCs()) do
        ensureHighlight(model, config)
    end
end

function HighlightESP.disable()
    HighlightESP.enabled = false
    for model, _ in pairs(HighlightESP.trackedModels) do
        removeHighlight(model)
    end
    HighlightESP.trackedModels = {}
end

-- Appelé à chaque refresh NPC (heartbeat) pour sync ajouts/retraits
function HighlightESP.sync(npcManager, config)
    if not HighlightESP.enabled then return end

    local active = npcManager:getActiveNPCs()

    -- Ajoute les nouveaux NPCs
    for model, _ in pairs(active) do
        if not HighlightESP.trackedModels[model] or not HighlightESP.trackedModels[model].Parent then
            ensureHighlight(model, config)
        end
    end

    -- Retire les NPCs morts
    for model, _ in pairs(HighlightESP.trackedModels) do
        if not active[model] then
            removeHighlight(model)
        end
    end
end

-- Met à jour fill/outline/transparence en temps réel (appelé par les sliders)
function HighlightESP.updateAll(npcManager, config)
    if not HighlightESP.enabled then return end
    for model, _ in pairs(npcManager:getActiveNPCs()) do
        ensureHighlight(model, config)
    end
end

function HighlightESP.isEnabled()
    return HighlightESP.enabled
end

return HighlightESP
