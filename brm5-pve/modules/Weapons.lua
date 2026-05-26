-- Weapons.lua
-- Module complet de modification des propriétés d'armes

local Weapons = {}

function Weapons.patchWeapons(replicatedStorage, patchOptions)
    local weaponsFolder = replicatedStorage:FindFirstChild("Shared")
        and replicatedStorage.Shared:FindFirstChild("Configs")
        and replicatedStorage.Shared.Configs:FindFirstChild("Weapon")
        and replicatedStorage.Shared.Configs.Weapon:FindFirstChild("Weapons_Player")
    
    if not weaponsFolder then return end

    for _, platform in pairs(weaponsFolder:GetChildren()) do
        if platform.Name:match("^Platform_") then
            for _, weapon in pairs(platform:GetChildren()) do
                for _, child in pairs(weapon:GetChildren()) do
                    if child:IsA("ModuleScript") and child.Name:match("^Receiver%.") then
                        local success, receiver = pcall(require, child)
                        if success and receiver and receiver.Config and receiver.Config.Tune then
                            local tune = receiver.Config.Tune
                            
                            -- 1. Recoil, Spread, Sway, Shake
                            if patchOptions.recoil then
                                tune.Recoil_X = 0 
                                tune.Recoil_Z = 0 
                                tune.RecoilForce_Tap = 0
                                tune.RecoilForce_Impulse = 0
                                tune.Recoil_Camera = 0
                            end
                            
                            if patchOptions.spread then
                                tune.Spread_Max = 0
                                tune.Spread_Recovery = 0
                                tune.Spread_Shot = 0
                            end

                            if patchOptions.sway then
                                tune.Sway_Intensity = 0
                                tune.Sway_Bob = 0
                            end

                            -- 2. ADS et Equip
                            if patchOptions.ads then
                                tune.ADS_Speed = 999 -- Instant ADS
                            end

                            if patchOptions.equip then
                                tune.Equip_Time = 0
                            end

                            -- 3. Bullet Speed (Instant Bullet)
                            if patchOptions.bulletVelocity then
                                tune.Bullet_Velocity = 99999
                            end

                            -- 4. Firemode Unlock
                            if patchOptions.firemodes then 
                                -- 3=Auto, 2=Burst, 1=Semi, 0=Safe
                                tune.Firemodes = {3, 2, 1} 
                            end

                            -- 5. Force Headshot & Shake
                            if patchOptions.forceHeadshot then
                                tune.Headshot_Multiplier = 999 -- Force le multiplicateur critique
                            end
                            
                            if patchOptions.cameraShake then
                                tune.Camera_Shake = 0
                            end
                        end
                    end
                end
            end
        end
    end
end

return Weapons