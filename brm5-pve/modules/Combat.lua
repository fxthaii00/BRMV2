-- Combat.lua
local Combat = {}

-- 1. Silent Aim
function Combat.SilentAim(remoteName, getTargetCallback)
    local old; old = hookmetamethod(game, "__namecall", function(self, ...)
        local args = {...}
        if getnamecallmethod() == "FireServer" and self.Name == remoteName then
            local target = getTargetCallback()
            if target then args[1] = target.Position end
        end
        return old(self, unpack(args))
    end)
end

-- 2. FOV Control
local circle = Drawing.new("Circle")
function Combat.UpdateFOV(radius, visible, position)
    circle.Radius = radius
    circle.Visible = visible
    circle.Position = position
end

-- 3. Bullet Drop Compensation
function Combat.CalculateBulletDrop(targetPos, bulletSpeed, gravity)
    local dist = (targetPos - game.Workspace.CurrentCamera.CFrame.Position).Magnitude
    local time = dist / bulletSpeed
    return targetPos + Vector3.new(0, (0.5 * gravity * time^2), 0)
end

-- 4. Movement Prediction
function Combat.PredictMovement(targetPart, bulletSpeed)
    local velocity = targetPart.Velocity
    local dist = (targetPart.Position - game.Workspace.CurrentCamera.CFrame.Position).Magnitude
    return targetPart.Position + (velocity * (dist / bulletSpeed))
end

-- 5. Hitbox Expander
function Combat.ExpandHitbox(targetRoot, size)
    targetRoot.Size = size
    targetRoot.Transparency = 0.5
    targetRoot.CanCollide = false
end

-- 6. Ragebot
function Combat.Ragebot(target)
    if target then
        -- Logique d'attaque automatique ici
    end
end

-- 7. Priority Targets
function Combat.SortByPriority(players)
    table.sort(players, function(a, b)
        return a.Character.Humanoid.Health < b.Character.Humanoid.Health
    end)
    return players
end

return Combat