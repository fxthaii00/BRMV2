-- Vehicle.lua
-- Module de contrôle et manipulation des véhicules

local Vehicle = {}
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

Vehicle.Config = {
    SpeedMultiplier = 2,
    FlyEnabled = false,
    Noclip = false
}

-- 1. Vehicle Speed Mods
function Vehicle:ApplySpeed(vehicleModel)
    local seat = vehicleModel:FindFirstChildOfClass("VehicleSeat")
    if seat then
        seat:GetPropertyChangedSignal("Throttle"):Connect(function()
            if seat.Throttle ~= 0 then
                vehicleModel.PrimaryPart.Velocity = vehicleModel.PrimaryPart.CFrame.LookVector * (seat.Throttle * 50 * Vehicle.Config.SpeedMultiplier)
            end
        end)
    end
end

-- 2. Teleport Vehicle
function Vehicle:Teleport(targetCFrame)
    local char = LocalPlayer.Character
    local vehicle = char and char:FindFirstChild("Humanoid").SeatPart and char.Humanoid.SeatPart.Parent
    if vehicle then
        vehicle:SetPrimaryPartCFrame(targetCFrame)
    end
end

-- 3. Vehicle Drop Off (Appelle le véhicule vers le joueur)
function Vehicle:DropOff(vehicleModel)
    local pos = LocalPlayer.Character.HumanoidRootPart.Position + Vector3.new(0, 5, 0)
    vehicleModel:SetPrimaryPartCFrame(CFrame.new(pos))
end

-- 4. Vehicle Fly
function Vehicle:Fly(vehicleModel, enabled)
    local root = vehicleModel.PrimaryPart
    if enabled then
        local bv = Instance.new("BodyVelocity", root)
        bv.Name = "VehicleFly"
        bv.MaxForce = Vector3.new(1/0, 1/0, 1/0)
        bv.Velocity = Vector3.new(0, 0, 0)
    else
        if root:FindFirstChild("VehicleFly") then root.VehicleFly:Destroy() end
    end
end

-- 5. Vehicle Noclip
function Vehicle:Noclip(vehicleModel, enabled)
    for _, part in pairs(vehicleModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not enabled
        end
    end
end

-- 6. Vehicle Kill (Farmer les ennemis)
-- Méthode : Applique une vélocité extrême sur les ennemis touchés par le véhicule
function Vehicle:KillEnemies(vehicleModel)
    vehicleModel.PrimaryPart.Touched:Connect(function(hit)
        local hum = hit.Parent:FindFirstChild("Humanoid")
        if hum and hum.Parent ~= LocalPlayer.Character then
            hum.Health = 0 -- Insta-kill au contact du véhicule
        end
    end)
end

return Vehicle