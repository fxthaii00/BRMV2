-- Configuration Module
local Config = {}
local HttpService = game:GetService("HttpService")

Config.CONFIG_FILE = "brmv2_pve_config.json"
Config.guiVisible = true
Config.currentToggleKey = "Home"
Config.savedGuiPos = UDim2.new(0.5, 0, 0.5, 0)
Config.savedBtnPos = UDim2.new(0, 50, 0.5, 0)

-- Example settings
Config.highlightEnabled = false
Config.aimEnabled = false

function Config:serialize()
    return {
        currentToggleKey = self.currentToggleKey,
        savedGuiPos = {X = self.savedGuiPos.X.Offset, Y = self.savedGuiPos.Y.Offset},
        savedBtnPos = {X = self.savedBtnPos.X.Offset, Y = self.savedBtnPos.Y.Offset},
        highlightEnabled = self.highlightEnabled,
        aimEnabled = self.aimEnabled
    }
end

function Config:applySavedData(data)
    if not data then return end
    self.currentToggleKey = data.currentToggleKey or "Home"
    if data.savedGuiPos then self.savedGuiPos = UDim2.new(0, data.savedGuiPos.X, 0, data.savedGuiPos.Y) end
    if data.savedBtnPos then self.savedBtnPos = UDim2.new(0, data.savedBtnPos.X, 0, data.savedBtnPos.Y) end
    self.highlightEnabled = data.highlightEnabled or false
    self.aimEnabled = data.aimEnabled or false
end

function Config:save()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, self:serialize())
    if ok then pcall(writefile, self.CONFIG_FILE, encoded) end
end

function Config:load()
    if not isfile or not isfile(self.CONFIG_FILE) then return end
    local ok, raw = pcall(readfile, self.CONFIG_FILE)
    if ok then
        local okDec, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if okDec then self:applySavedData(data) end
    end
end

return Config
