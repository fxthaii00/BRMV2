-- Main Entry Point
local Services = {
    UserInputService = game:GetService("UserInputService"),
    RunService = game:GetService("RunService"),
    CoreGui = game:GetService("CoreGui")
}

local Config = loadstring(game:HttpGet("https://raw.githubusercontent.com/fxthaii00/BRMV2/main/brm5-pve/modules/config.lua"))()
local GUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/fxthaii00/BRMV2/main/brm5-pve/modules/gui.lua"))()

Config:load()

local callbacks = {
    onVisibilityToggle = function()
        Config.guiVisible = not Config.guiVisible
        GUI:toggleVisibility(Config.guiVisible)
        Config:save()
    end,
    onHighlightsToggle = function(enabled)
        Config.highlightEnabled = enabled
        Config:save()
    end
}

local guiInstance = GUI:init(Services, Config, callbacks)

Services.UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode[Config.currentToggleKey] then
        callbacks.onVisibilityToggle()
    end
end)
