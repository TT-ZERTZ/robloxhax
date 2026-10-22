-- ============================================
-- ZERTZ ESP - Ultra Dark Blue Custom UI (V2)
-- ============================================

if _G.HubCleanup then _G.HubCleanup() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

-- ═══ STATE CONFIG ═══
local espEnabled = false
local boxEnabled = false
local tracersEnabled = false
local distanceEnabled = false

-- Preset Color List for Customization
local colorPresets = {
    Color3.fromRGB(0, 150, 255),  -- Electric Blue
    Color3.fromRGB(0, 255, 200),  -- Neon Cyan
    Color3.fromRGB(255, 50, 80),  -- Crimson Red
    Color3.fromRGB(50, 255, 100), -- Lime Green
    Color3.fromRGB(180, 70, 255)  -- Purple
}
local currentColorIndex = 1
local currentESPColor = colorPresets[currentColorIndex]

local espObjects = {}
local connections = {}

-- ═══ UTILITY FUNCTIONS ═══
local function isAlive(p)
    local char = p and p.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    return hum and root and hum.Health > 0
end

local function isValidTarget(p)
    if p == LocalPlayer then return false end
    if not isAlive(p) then return false end
    if p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then return false end
    return true
end

-- ═══ ESP MANAGEMENT ═══
local function createESP(target)
    if espObjects[target] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 0.85
    highlight.OutlineTransparency = 0
    highlight.FillColor = currentESPColor
    highlight.OutlineColor = currentESPColor
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Filled = false
    box.Color = currentESPColor
    box.Transparency = 1
    box.Visible = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1.2
    tracer.Color = currentESPColor
    tracer.Transparency = 0.8
    tracer.Visible = false
    
    local text = Drawing.new("Text")
    text.Size = 13
    text.Center = true
    text.Outline = true
    text.Color = currentESPColor
    text.Visible = false
    
    espObjects[target] = {
        Highlight = highlight,
        Box = box,
        Tracer = tracer,
        Text = text
    }
end

local function removeESP(target)
    local data = espObjects[target]
    if data then
        if data.Highlight then data.Highlight:Destroy() end
        if data.Box then data.Box:Remove() end
        if data.Tracer then data.Tracer:Remove() end
        if data.Text then data.Text:Remove() end
        espObjects[target] = nil
    end
end

-- ═══ RENDER LOOP ═══
connections.render = RunService.RenderStepped:Connect(function()
    local viewportSize = Camera.ViewportSize
    local bottomCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y)
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if isValidTarget(p) then
                createESP(p)
                local data = espObjects[p]
                local char = p.Character
                local rootPart = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
                
                if char and rootPart then
                    if espEnabled then
                        data.Highlight.Parent = char
                    else
                        data.Highlight.Parent = nil
                    end
                    
                    local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                    
                    if onScreen then
                        -- Box ESP (Feet to Head)
                        if boxEnabled and espEnabled then
                            local headWorld = rootPart.Position + Vector3.new(0, 2.5, 0)
                            local feetWorld = rootPart.Position - Vector3.new(0, 3.5, 0)
                            
                            local headScreen = Camera:WorldToViewportPoint(headWorld)
                            local feetScreen = Camera:WorldToViewportPoint(feetWorld)
                            
                            local height = math.abs(headScreen.Y - feetScreen.Y)
                            local width = height / 1.5
                            
                            data.Box.Size = Vector2.new(width, height)
                            data.Box.Position = Vector2.new(headScreen.X - (width / 2), headScreen.Y)
                            data.Box.Visible = true
                        else
                            data.Box.Visible = false
                        end

                        -- Tracers
                        if tracersEnabled and espEnabled then
                            local feetWorld = rootPart.Position - Vector3.new(0, 3.5, 0)
                            local feetScreen = Camera:WorldToViewportPoint(feetWorld)
                            
                            data.Tracer.From = bottomCenter
                            data.Tracer.To = Vector2.new(feetScreen.X, feetScreen.Y)
                            data.Tracer.Visible = true
                        else
                            data.Tracer.Visible = false
                        end
                        
                        -- Distance Indicator
                        if distanceEnabled and espEnabled and LocalPlayer.Character then
                            local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if localRoot then
                                local distance = math.floor((localRoot.Position - rootPart.Position).Magnitude)
                                data.Text.Text = distance .. " studs"
                                data.Text.Position = Vector2.new(screenPos.X, screenPos.Y + (boxEnabled and (data.Box.Size.Y / 2 + 5) or 15))
                                data.Text.Visible = true
                            else
                                data.Text.Visible = false
                            end
                        else
                            data.Text.Visible = false
                        end
                    else
                        data.Box.Visible = false
                        data.Tracer.Visible = false
                        data.Text.Visible = false
                    end
                else
                    data.Highlight.Parent = nil
                    data.Box.Visible = false
                    data.Tracer.Visible = false
                    data.Text.Visible = false
                end
            else
                removeESP(p)
            end
        end
    end
end)

connections.removing = Players.PlayerRemoving:Connect(function(p) removeESP(p) end)

-- ═══ CUSTOM UI DESIGN ═══
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZertzESP_UltraUI"
ScreenGui.ResetOnSpawn = false

pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Draggable Function (Mobile Touch & Mouse)
local function makeDraggable(guiObject, dragHandle)
    dragHandle = dragHandle or guiObject
    local dragging, dragStart, startPos
    
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Floating Draggable Open Button for Mobile / PC
local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.new(0, 48, 0, 48)
OpenButton.Position = UDim2.new(0, 15, 0, 180)
OpenButton.BackgroundColor3 = Color3.fromRGB(12, 18, 30)
OpenButton.TextColor3 = Color3.fromRGB(0, 170, 255)
OpenButton.TextSize = 20
OpenButton.Font = Enum.Font.GothamBold
OpenButton.Text = "Z"
OpenButton.Parent = ScreenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(0, 12)
OpenCorner.Parent = OpenButton

local OpenStroke = Instance.new("UIStroke")
OpenStroke.Color = Color3.fromRGB(0, 120, 255)
OpenStroke.Thickness = 1.5
OpenStroke.Parent = OpenButton

makeDraggable(OpenButton)

-- Main Window Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 290, 0, 360)
MainFrame.Position = UDim2.new(0.5, -145, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(25, 40, 65)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Top Bar Header
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(14, 22, 36)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 14)
TopCorner.Parent = TopBar

local TopCover = Instance.new("Frame")
TopCover.Size = UDim2.new(1, 0, 0, 12)
TopCover.Position = UDim2.new(0, 0, 1, -12)
TopCover.BackgroundColor3 = Color3.fromRGB(14, 22, 36)
TopCover.BorderSizePixel = 0
TopCover.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
TitleLabel.TextSize = 15
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "ZERTZ ESP"
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

makeDraggable(MainFrame, TopBar)

-- Container for Toggles & Controls
local ContentContainer = Instance.new("ScrollingFrame")
ContentContainer.Size = UDim2.new(1, -20, 1, -55)
ContentContainer.Position = UDim2.new(0, 10, 0, 48)
ContentContainer.BackgroundTransparency = 1
ContentContainer.BorderSizePixel = 0
ContentContainer.CanvasSize = UDim2.new(0, 0, 0, 310)
ContentContainer.ScrollBarThickness = 2
ContentContainer.ScrollBarImageColor3 = Color3.fromRGB(0, 120, 255)
ContentContainer.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 8)
UIList.Parent = ContentContainer

-- Builder for Modern Toggles
local function createToggle(name, callback)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, 0, 0, 42)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(14, 20, 32)
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = ContentContainer
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = toggleBtn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(22, 32, 50)
    stroke.Thickness = 1
    stroke.Parent = toggleBtn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(180, 200, 225)
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggleBtn

    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 10, 0, 10)
    statusDot.Position = UDim2.new(1, -22, 0.5, -5)
    statusDot.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
    statusDot.BorderSizePixel = 0
    statusDot.Parent = toggleBtn

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = statusDot

    local state = false
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            toggleBtn.BackgroundColor3 = Color3.fromRGB(12, 30, 55)
            stroke.Color = Color3.fromRGB(0, 130, 255)
            statusDot.BackgroundColor3 = Color3.fromRGB(0, 210, 255)
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            toggleBtn.BackgroundColor3 = Color3.fromRGB(14, 20, 32)
            stroke.Color = Color3.fromRGB(22, 32, 50)
            statusDot.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
            label.TextColor3 = Color3.fromRGB(180, 200, 225)
        end
        callback(state)
    end)
end

-- Builder for Custom Buttons
local function createButton(name, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = color
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.Parent = ContentContainer
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.85
    stroke.Thickness = 1
    stroke.Parent = btn
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- Construct Features
createToggle("ESP Outline", function(v)
    espEnabled = v
    if not v then
        for _, data in pairs(espObjects) do
            if data.Highlight then data.Highlight.Parent = nil end
            if data.Box then data.Box.Visible = false end
            if data.Tracer then data.Tracer.Visible = false end
            if data.Text then data.Text.Visible = false end
        end
    end
end)

createToggle("Box ESP", function(v)
    boxEnabled = v
end)

createToggle("Tracers", function(v)
    tracersEnabled = v
end)

createToggle("Distance Indicator", function(v)
    distanceEnabled = v
end)

-- Dynamic Preset Color Switcher Button
local colorBtn
colorBtn = createButton("Cycle Theme Color", Color3.fromRGB(18, 30, 52), function()
    currentColorIndex = (currentColorIndex % #colorPresets) + 1
    currentESPColor = colorPresets[currentColorIndex]
    
    for _, data in pairs(espObjects) do
        if data.Highlight then
            data.Highlight.FillColor = currentESPColor
            data.Highlight.OutlineColor = currentESPColor
        end
        if data.Box then data.Box.Color = currentESPColor end
        if data.Tracer then data.Tracer.Color = currentESPColor end
        if data.Text then data.Text.Color = currentESPColor end
    end
end)

createButton("Destroy UI & Exit", Color3.fromRGB(140, 30, 40), function()
    if _G.HubCleanup then
        _G.HubCleanup()
    end
end)

-- Toggle Menu Visibility via Floating 'Z' Button
OpenButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Clean Exit Handler
_G.HubCleanup = function()
    for _, c in pairs(connections) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    connections = {}
    for p, _ in pairs(espObjects) do
        removeESP(p)
    end
    espObjects = {}
    if ScreenGui then
        ScreenGui:Destroy()
    end
    _G.HubCleanup = nil
end

print("ZERTZ ESP Ultra Custom UI Active!")
