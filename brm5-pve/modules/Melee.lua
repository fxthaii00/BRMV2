-- Melee.lua
-- Module de modification des armes de mêlée

local Melee = {}

-- Applique les patchs sur les armes de mêlée
-- Note : Vérifiez le chemin d'accès dans votre ReplicatedStorage spécifique
function Melee.patchMelee(replicatedStorage, patchOptions)
    local meleeFolder = replicatedStorage:FindFirstChild("Shared")
        and replicatedStorage.Shared:FindFirstChild("Configs")
        and replicatedStorage.Shared.Configs:FindFirstChild("Melee")
    
    if not meleeFolder then return end

    for _, weaponModule in pairs(meleeFolder:GetDescendants()) do
        if weaponModule:IsA("ModuleScript") then
            local success, weaponData = pcall(require, weaponModule)
            if success and weaponData and weaponData.Config then
                local config = weaponData.Config

                -- 1. Melee Force Headshot
                -- Force le multiplicateur de dégâts pour la tête à une valeur élevée
                if patchOptions.forceHeadshot then
                    config.HeadshotMultiplier = 999
                end

                -- 2. Extended Reach
                -- Augmente la distance maximale du raycast ou du hitbox de détection
                if patchOptions.extendedReach then
                    config.Reach = config.Reach * 2 -- Double la portée
                    config.MaxDistance = 50 -- Distance arbitraire élevée
                end

                -- 3. Fast Swing
                -- Réduit le temps d'animation et le cooldown entre les coups
                if patchOptions.fastSwing then
                    config.SwingCooldown = 0.05
                    config.AnimationSpeed = 2
                end
            end
        end
    end
end

return Melee