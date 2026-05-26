local SilentAim = {}

-- Configuration de base
SilentAim.Enabled = true
SilentAim.TargetPart = "HumanoidRootPart" -- On cible la RootPart modifiée par TargetSizing
SilentAim.WallCheck = true 

local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Vérification de visibilité (Raycast)
local function isVisible(targetPart)
    if not SilentAim.WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    
    local ray = workspace:Raycast(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position).Unit * 500, params)
    return ray and ray.Instance and ray.Instance:IsDescendantOf(targetPart.Parent)
end

-- Recherche de la cible la plus proche dans le champ de vision
function SilentAim:GetTarget(npcManager)
    local closestTarget = nil
    local minDistance = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    -- On scanne les NPCs actifs gérés par votre système
    for _, data in pairs(npcManager:getActiveNPCs()) do
        local root = data.root
        if root then
            local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen and isVisible(root) then
                local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closestTarget = root
                end
            end
        end
    end
    return closestTarget
end

-- Initialisation du hook de tir
function SilentAim:Init(npcManager, remoteName)
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local args = {...}
        local method = getnamecallmethod()

        if SilentAim.Enabled and method == "FireServer" and self.Name == remoteName then
            local target = SilentAim:GetTarget(npcManager)
            if target then
                -- Redirection du tir vers la position de la RootPart (la hitbox élargie)
                args[1] = target.Position 
            end
        end

        return oldNamecall(self, unpack(args))
    end)
end

return SilentAim
