-- Configuration Module
-- Contains all settings, constants, and state variables

local Config = {}
local HttpService = game:GetService("HttpService")

-- CONSTANTS
Config.RAYCAST_COOLDOWN = 0.2
Config.MARKER_MAX_PER_STEP = 12
Config.TARGET_SYNC_INTERVAL = 0.25
Config.NPC_REFRESH_INTERVAL = 0.5
Config.TARGET_BOX_SIZE = Vector3.new(15, 15, 15) -- Size of the adjusted target bounds
Config.TARGET_BOX_TRANSPARENCY = 0.85           -- 0 = opaque, 1 = invisible
Config.TARGET_BOX_COLOR_R = 255
Config.TARGET_BOX_COLOR_G = 255
Config.TARGET_BOX_COLOR_B = 255
Config.TARGET_BOX_COLOR = Color3.fromRGB(255, 255, 255)
Config.MAX_NPC_DETECTION_RADIUS = 3000
Config.npcDetectionRadius = Config.MAX_NPC_DETECTION_RADIUS
Config.CONFIG_FILE = "brm5_pve_config.json"

-- TOGGLES (State)
Config.highlightEnabled = false  -- Visibility markers
Config.sizingEnabled = false     -- Target sizing
Config.showTargetBox = false     -- Shows target bounds
Config.fullBrightEnabled = false -- Removes shadows/darkness
Config.guiVisible = true         -- Menu visibility
Config.isUnloaded = false        -- To stop the script

-- AIM ASSIST
Config.aimEnabled  = false
Config.fovEnabled  = true
Config.fovRadius   = 120
Config.smoothing   = 70    -- 0 = instantané, 99 = très lent
Config.DEADZONE    = 2     -- pixels, en dessous desquels on ne bouge pas la souris
Config._npcManager = nil   -- injecté depuis main.lua après init

-- WEAPON PATCHES
Config.patchOptions = { 
    recoil = false, 
    firemodes = false 
}

-- COLORS (RGB: 0 to 255)
Config.visibleR, Config.visibleG, Config.visibleB = 0, 255, 0    -- Green for visible targets
Config.hiddenR, Config.hiddenG, Config.hiddenB = 255, 0, 0       -- Red for occluded targets
Config.visibleColor = Color3.fromRGB(Config.visibleR, Config.visibleG, Config.visibleB)
Config.hiddenColor = Color3.fromRGB(Config.hiddenR, Config.hiddenG, Config.hiddenB)

-- ESP HIGHLIGHT
Config.espHighlightEnabled    = false
Config.espFillR               = 255
Config.espFillG               = 0
Config.espFillB               = 0
Config.espFillTransparency    = 0.5
Config.espOutlineR            = 255
Config.espOutlineG            = 255
Config.espOutlineB            = 255
Config.espOutlineTransparency = 0
Config.espFillColor           = Color3.fromRGB(255, 0, 0)
Config.espOutlineColor        = Color3.fromRGB(255, 255, 255)

-- Update color function
function Config:updateVisibleColor(r, g, b)
    if r then self.visibleR = r end
    if g then self.visibleG = g end
    if b then self.visibleB = b end
    self.visibleColor = Color3.fromRGB(self.visibleR, self.visibleG, self.visibleB)
end

function Config:updateHiddenColor(r, g, b)
    if r then self.hiddenR = r end
    if g then self.hiddenG = g end
    if b then self.hiddenB = b end
    self.hiddenColor = Color3.fromRGB(self.hiddenR, self.hiddenG, self.hiddenB)
end

function Config:updateTargetBoxColor(r, g, b)
    if r then self.TARGET_BOX_COLOR_R = r end
    if g then self.TARGET_BOX_COLOR_G = g end
    if b then self.TARGET_BOX_COLOR_B = b end
    self.TARGET_BOX_COLOR = Color3.fromRGB(self.TARGET_BOX_COLOR_R, self.TARGET_BOX_COLOR_G, self.TARGET_BOX_COLOR_B)
end

function Config:updateTargetBoxSize(value)
    local s = math.clamp(math.floor(value or 15), 1, 20)
    self.TARGET_BOX_SIZE = Vector3.new(s, s, s)
end

function Config:updateTargetBoxTransparency(value)
    self.TARGET_BOX_TRANSPARENCY = math.clamp(value or 0.85, 0, 1)
end

function Config:updateEspFillColor(r, g, b)
    if r then self.espFillR = r end
    if g then self.espFillG = g end
    if b then self.espFillB = b end
    self.espFillColor = Color3.fromRGB(self.espFillR, self.espFillG, self.espFillB)
end

function Config:updateEspOutlineColor(r, g, b)
    if r then self.espOutlineR = r end
    if g then self.espOutlineG = g end
    if b then self.espOutlineB = b end
    self.espOutlineColor = Color3.fromRGB(self.espOutlineR, self.espOutlineG, self.espOutlineB)
end

function Config:updateNPCDetectionRadius(value)
    self.npcDetectionRadius = math.clamp(
        math.floor(value or self.npcDetectionRadius),
        0,
        self.MAX_NPC_DETECTION_RADIUS
    )
end

function Config:isNPCDetectionEnabled()
    return self.sizingEnabled or self.showTargetBox or self.highlightEnabled
end

function Config:serialize()
    return {
        highlightEnabled = self.highlightEnabled,
        sizingEnabled = self.sizingEnabled,
        showTargetBox = self.showTargetBox,
        fullBrightEnabled = self.fullBrightEnabled,
        npcDetectionRadius = self.npcDetectionRadius,
        patchOptions = {
            recoil = self.patchOptions.recoil,
            firemodes = self.patchOptions.firemodes
        },
        visibleR = self.visibleR,
        visibleG = self.visibleG,
        visibleB = self.visibleB,
        hiddenR = self.hiddenR,
        hiddenG = self.hiddenG,
        hiddenB = self.hiddenB,
        TARGET_BOX_TRANSPARENCY = self.TARGET_BOX_TRANSPARENCY,
        TARGET_BOX_SIZE = self.TARGET_BOX_SIZE.X,
        TARGET_BOX_COLOR_R = self.TARGET_BOX_COLOR_R,
        TARGET_BOX_COLOR_G = self.TARGET_BOX_COLOR_G,
        TARGET_BOX_COLOR_B = self.TARGET_BOX_COLOR_B,
        espHighlightEnabled    = self.espHighlightEnabled,
        espFillR               = self.espFillR,
        espFillG               = self.espFillG,
        espFillB               = self.espFillB,
        espFillTransparency    = self.espFillTransparency,
        espOutlineR            = self.espOutlineR,
        espOutlineG            = self.espOutlineG,
        espOutlineB            = self.espOutlineB,
        espOutlineTransparency = self.espOutlineTransparency,
        aimEnabled  = self.aimEnabled,
        fovEnabled  = self.fovEnabled,
        fovRadius   = self.fovRadius,
        smoothing   = self.smoothing,
    }
end

function Config:applySavedData(data)
    if type(data) ~= "table" then
        return
    end

    if data.highlightEnabled ~= nil then self.highlightEnabled = data.highlightEnabled end
    if data.sizingEnabled ~= nil then self.sizingEnabled = data.sizingEnabled end
    if data.showTargetBox ~= nil then self.showTargetBox = data.showTargetBox end
    if data.fullBrightEnabled ~= nil then self.fullBrightEnabled = data.fullBrightEnabled end
    if type(data.patchOptions) == "table" then
        if data.patchOptions.recoil ~= nil then self.patchOptions.recoil = data.patchOptions.recoil end
        if data.patchOptions.firemodes ~= nil then self.patchOptions.firemodes = data.patchOptions.firemodes end
    end

    self:updateVisibleColor(data.visibleR, data.visibleG, data.visibleB)
    self:updateHiddenColor(data.hiddenR, data.hiddenG, data.hiddenB)
    self:updateNPCDetectionRadius(data.npcDetectionRadius)
    if data.espHighlightEnabled ~= nil then self.espHighlightEnabled = data.espHighlightEnabled end
    self:updateEspFillColor(data.espFillR, data.espFillG, data.espFillB)
    self:updateEspOutlineColor(data.espOutlineR, data.espOutlineG, data.espOutlineB)
    if data.espFillTransparency    ~= nil then self.espFillTransparency    = data.espFillTransparency    end
    if data.espOutlineTransparency ~= nil then self.espOutlineTransparency = data.espOutlineTransparency end
    if data.aimEnabled ~= nil then self.aimEnabled = data.aimEnabled end
    if data.fovEnabled ~= nil then self.fovEnabled = data.fovEnabled end
    if data.fovRadius  ~= nil then self.fovRadius  = data.fovRadius  end
    if data.smoothing  ~= nil then self.smoothing  = data.smoothing  end
    self:updateTargetBoxColor(data.TARGET_BOX_COLOR_R, data.TARGET_BOX_COLOR_G, data.TARGET_BOX_COLOR_B)
    if data.TARGET_BOX_TRANSPARENCY ~= nil then self:updateTargetBoxTransparency(data.TARGET_BOX_TRANSPARENCY) end
    if data.TARGET_BOX_SIZE ~= nil then self:updateTargetBoxSize(data.TARGET_BOX_SIZE) end
end

function Config:save()
    if type(writefile) ~= "function" then
        return false
    end

    local okEncode, encoded = pcall(HttpService.JSONEncode, HttpService, self:serialize())
    if not okEncode then
        return false
    end

    local okWrite = pcall(writefile, self.CONFIG_FILE, encoded)
    return okWrite
end

function Config:load()
    if type(isfile) ~= "function" or type(readfile) ~= "function" or not isfile(self.CONFIG_FILE) then
        return false
    end

    local okRead, raw = pcall(readfile, self.CONFIG_FILE)
    if not okRead or type(raw) ~= "string" or raw == "" then
        return false
    end

    local okDecode, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not okDecode then
        return false
    end

    self:applySavedData(data)
    return true
end

-- Fonctions d'assistance pour les Sliders individuels du TargetBox
function Config:updateTargetBoxR(value)
    self:updateTargetBoxColor(value, self.TARGET_BOX_COLOR_G, self.TARGET_BOX_COLOR_B)
end

function Config:updateTargetBoxG(value)
    self:updateTargetBoxColor(self.TARGET_BOX_COLOR_R, value, self.TARGET_BOX_COLOR_B)
end

function Config:updateTargetBoxB(value)
    self:updateTargetBoxColor(self.TARGET_BOX_COLOR_R, self.TARGET_BOX_COLOR_G, value)
end

return Config
