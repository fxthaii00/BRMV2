-- UI Module
local GUI = {}

function GUI:init(Services, Config, callbacks)
    local screenGui = Instance.new("ScreenGui", Services.CoreGui)
    self.screenGui = screenGui

    self.mainFrame = Instance.new("Frame", screenGui)
    self.mainFrame.Size = UDim2.new(0, 200, 0, 300)
    self.mainFrame.Position = Config.savedGuiPos
    self.mainFrame.Visible = Config.guiVisible
    self.mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    
    self.toggleButton = Instance.new("TextButton", screenGui)
    self.toggleButton.Size = UDim2.new(0, 100, 0, 50)
    self.toggleButton.Position = Config.savedBtnPos
    self.toggleButton.Text = "Menu"
    self.toggleButton.MouseButton1Click:Connect(function()
        callbacks.onVisibilityToggle()
    end)
    
    return self
end

function GUI:toggleVisibility(visible)
    self.mainFrame.Visible = visible
    return visible
end

function GUI:destroy()
    self.screenGui:Destroy()
end

return GUI
