-- World.lua
-- Module de contrôle de l'environnement visuel

local World = {}
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

World.Config = {
    FullBright = true,
    NoShadows = true,
    Time = 12,
    Brightness = 2,
    Ambient = Color3.new(1, 1, 1),
    NoFog = true,
    NoAtmosphere = true,
    NoClouds = true,
    NoBloom = true,
    NoBlur = true,
    NoColorCorrection = true,
    NoSunRays = true,
    NoDepthOfField = true
}

-- 1. Eclairage global
function World:UpdateLighting()
    if World.Config.FullBright then
        Lighting.Brightness = World.Config.Brightness
        Lighting.ClockTime = World.Config.Time
        Lighting.Ambient = World.Config.Ambient
        Lighting.GlobalShadows = not World.Config.NoShadows
        Lighting.FogEnd = World.Config.NoFog and 100000 or Lighting.FogEnd
    end
end

-- 2. Suppression des effets post-process
function World:RemoveEffects()
    local effects = {
        Atmosphere = World.Config.NoAtmosphere,
        Clouds = World.Config.NoClouds,
        BloomEffect = World.Config.NoBloom,
        BlurEffect = World.Config.NoBlur,
        ColorCorrectionEffect = World.Config.NoColorCorrection,
        SunRaysEffect = World.Config.NoSunRays,
        DepthOfFieldEffect = World.Config.NoDepthOfField
    }

    for className, enabled in pairs(effects) do
        if enabled then
            for _, child in pairs(Lighting:GetChildren()) do
                if child:IsA(className) then
                    child.Enabled = false
                end
            end
        end
    end
end

-- 3. World Removal (Map Clutter)
function World:RemoveClutter()
    -- Exemple : supprimer les débris ou objets décoratifs par nom
    local clutterNames = {"Grass", "Debris", "Leaf"}
    for _, obj in pairs(Workspace:GetDescendants()) do
        for _, name in ipairs(clutterNames) do
            if obj.Name:find(name) then
                obj:Destroy()
            end
        end
    end
end

function World:Init()
    self:UpdateLighting()
    self:RemoveEffects()
    
    -- Listener pour maintenir les changements
    game:GetService("RunService").RenderStepped:Connect(function()
        if World.Config.FullBright then self:UpdateLighting() end
    end)
end

return World