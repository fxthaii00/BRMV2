-- GUI Module – BRM5 PVE
local GUI = {}
local C = {
    bg = Color3.fromRGB(8, 8, 10),
    header = Color3.fromRGB(12, 12, 15),
    cardBg = Color3.fromRGB(14, 14, 18),
    btnOn = Color3.fromRGB(130, 50, 255),
    btnOff = Color3.fromRGB(25, 25, 30)
}

function GUI:init(Services, Config, callbacks)
    -- Création du conteneur principal
    local screenGui = Instance.new("ScreenGui", Services.CoreGui)
    screenGui.Name = "BRM5_Toolkit_GUI"
    self.screenGui = screenGui

    -- Fenêtre principale
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Size = UDim2.new(0, 450, 0, 300)
    mainFrame.Position = Config.savedGuiPos or UDim2.new(0.5, -225, 0.5, -150)
    mainFrame.BackgroundColor3 = C.bg
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = Config.guiVisible
    self.mainFrame = mainFrame

    -- Header (Titre)
    local header = Instance.new("Frame", mainFrame)
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3 = C.header
    
    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1, 0, 1, 0)
    title.Text = "BRM5 ADVANCED TOOLKIT - Version 7.1"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundTransparency = 1

    -- Bouton de fermeture (Exemple)
    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 40, 1, 0)
    closeBtn.Position = UDim2.new(1, -40, 0, 0)
    closeBtn.Text = "X"
    closeBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
    end)

    self.mainFrame = mainFrame
    return self
end

function GUI:toggleVisibility(visible)
    if self.mainFrame then
        self.mainFrame.Visible = visible
    end
end

return GUI
