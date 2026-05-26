-- Visual.lua
-- Module tout-en-un pour les fonctionnalités visuelles (ESP & Chams)

local Visual = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HighlightESP = require(script.Parent.highlight) -- Réutilise votre module highlight existant

Visual.Config = {
    PlayerESP = true,
    ZombieESP = true,
    NPCESP = true,
    PriorityESP = true, -- Highlight spécial pour cibles prioritaires
    ChamsEnabled = true,
    Keybind = Enum.KeyCode.Insert
}

-- 1. Gestion des Highlights (Chams/Outline)
local function applyVisual(model, color, isPriority)
    local h = model:FindFirstChild("ESP_Highlight") or Instance.new("Highlight")
    h.Name = "ESP_Highlight"
    h.Adornee = model
    h.FillColor = isPriority and Color3.fromRGB(255, 215, 0) or color -- Jaune pour priorité
    h.OutlineColor = Color3.new(1, 1, 1)
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = model
end

-- 2. Logique principale de scan (Player, Zombie, NPC)
function Visual:Update(npcManager)
    if not Visual.Config.PlayerESP and not Visual.Config.NPCESP then return end

    -- Traitement des Joueurs
    if Visual.Config.PlayerESP then
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                applyVisual(player.Character, Color3.fromRGB(0, 255, 0), false)
            end
        end
    end

    -- Traitement des NPCs / Zombies (via votre NPCManager)
    for model, _ in pairs(npcManager:getActiveNPCs()) do
        local isZombie = model:FindFirstChild("ZombieTag") -- Exemple de check
        if (Visual.Config.ZombieESP and isZombie) or (Visual.Config.NPCESP and not isZombie) then
            applyVisual(model, Color3.fromRGB(255, 0, 0), false)
        end
    end
end

-- 3. ESP Keybinds
function Visual:InitKeybinds()
    game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Visual.Config.Keybind then
            Visual.Config.ChamsEnabled = not Visual.Config.ChamsEnabled
            print("ESP Toggled: " .. tostring(Visual.Config.ChamsEnabled))
        end
    end)
end

return Visual