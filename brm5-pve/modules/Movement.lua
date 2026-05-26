-- Movement.lua
-- Module de contrôle des capacités de mouvement et physiques

local Movement = {}
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Humanoid = nil -- Sera défini lors de l'initialisation

Movement.Config = {
    SpeedHack = false,
    SpeedValue = 25,
    AltSpeed = 50, -- Speed Modifier
    InfiniteStamina = true,
    SuperJump = false,
    JumpPower = 100,
    Fly = false,
    NoFallDamage = true,
    AntiHunger = true
}

-- 1. Gestion de la vitesse et des penalties
function Movement:UpdateSpeed()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Humanoid") then return end
    local hum = LocalPlayer.Character.Humanoid
    
    if Movement.Config.SpeedHack then
        hum.WalkSpeed = Movement.Config.SpeedValue
    end
    
    -- No Speed Penalties : force la vitesse normale même si le jeu essaie de la réduire
    if Movement.Config.NoSpeedPenalties then
        hum.WalkSpeed = math.max(hum.WalkSpeed, 16)
    end
end

-- 2. Stamina et Faim/Soif
function Movement:UpdateStats()
    local stats = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Stats")
    if stats then
        if Movement.Config.InfiniteStamina then
            -- Bypass si le jeu utilise une valeur de stamina dans un IntValue ou NumberValue
            local stamina = stats:FindFirstChild("Stamina")
            if stamina then stamina.Value = stamina.MaxValue end
        end
        if Movement.Config.AntiHunger then
            local hunger = stats:FindFirstChild("Hunger")
            if hunger then hunger.Value = 100 end
        end
    end
end

-- 3. Physique (Jump, Fall)
function Movement:ApplyPhysics()
    local char = LocalPlayer.Character
    if not char then return end
    
    -- Super Jump
    if Movement.Config.SuperJump then
        char.Humanoid.UseJumpPower = true
        char.Humanoid.JumpPower = Movement.Config.JumpPower
    end
    
    -- No Fall Damage (Hook sur la réception des dégâts)
    if Movement.Config.NoFallDamage then
        char.Humanoid.FallingDown = false
    end
end

-- 4. Fly (Simple implémentation)
function Movement:ToggleFly(enabled)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if enabled then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "FlightVelocity"
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.MaxForce = Vector3.new(1/0, 1/0, 1/0)
        bv.Parent = root
    else
        if root:FindFirstChild("FlightVelocity") then root.FlightVelocity:Destroy() end
    end
end

-- Initialisation
function Movement:Init()
    game:GetService("RunService").RenderStepped:Connect(function()
        self:UpdateSpeed()
        self:UpdateStats()
        self:ApplyPhysics()
    end)
end

return Movement