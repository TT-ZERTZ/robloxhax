-- ============================================
-- ZERTZ ESP - Advanced Custom UI (V3 Moondiety Style)
-- ============================================

if _G.HubCleanup then _G.HubCleanup() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
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
local teamCheckEnabled = false
local toggleKey = Enum.KeyCode.K
local waitingForKey = false

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
    if teamCheckEnabled and p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then 
        return false 
    end
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

-- ═══ RENDER LOOP (FIXED 8-CORNER PERSPECTIVE BOX) ═══
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
                        -- 8-Corner Bounding Box Calculation (Fixes perspective warping bug entirely)
                        if boxEnabled and espEnabled then
                            local cf, size = char:GetBoundingBox()
                            local corners = {
                                cf * CFrame.new(size.X/2, size.Y/2, size.Z/2),
                                cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2),
                                cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2),
                                cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2),
                                cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2),
                                cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2),
                                cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2),
                                cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),
                            }
                            
                            local minX, minY = math.huge, math.huge
                            local maxX, maxY = -math.huge, -math.huge
                            local boxVisible = true
                            
                            for _, corner in ipairs(corners) do
                                local cPos, cOnScreen = Camera:WorldToViewportPoint(corner.Position)
                                if not cOnScreen then boxVisible = false end
                                minX = math.min(minX, cPos.X)
                                minY = math.min(minY, cPos.Y)
                                maxX = math.max(maxX, cPos.X)
                                maxY = math.max(maxY, cPos.Y)
                            end
                            
                            if boxVisible then
                                data.Box.Size = Vector2.new(maxX - minX, maxY - minY)
                                data.Box.Position = Vector2.new(minX, minY)
                                data.Box.Visible = true
                            else
                                data.Box.Visible = false
                            end
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

-- ═══ UI CREATION (ANIMATED MOONDIETY THEME) ═══
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZertzESP_Animated"
ScreenGui.ResetOnSpawn = false

pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Draggable Helper
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

-- Floating Draggable Open Button
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

-- Main CanvasGroup (Enables Smooth Fade Animations)
local MainContainer = Instance.new("CanvasGroup")
MainContainer.Name = "MainContainer"
MainContainer.Size = UDim2.new(0, 340, 0, 390)
MainContainer.Position = UDim2.new(0.5, -170, 0.5, -195)
MainContainer.BackgroundTransparency = 1
MainContainer.GroupTransparency = 0
MainContainer.Visible = true
MainContainer.Parent = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(1, 0, 1, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = MainContainer

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(25, 40, 65)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Top Bar Header
local TopBar = Instance.new("Frame")
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
TitleLabel.Text = "ZERTZ ESP HUB"
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

makeDraggable(MainContainer, TopBar)

-- Tab Bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 35)
TabBar.Position = UDim2.new(0, 10, 0, 50)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabListLayout.Padding = UDim.new(0, 10)
TabListLayout.Parent = TabBar

-- Pages Container
local PagesContainer = Instance.new("Frame")
PagesContainer.Size = UDim2.new(1, -20, 1, -100)
PagesContainer.Position = UDim2.new(0, 10, 0, 92)
PagesContainer.BackgroundTransparency = 1
PagesContainer.Parent = MainFrame

local VisualsPage = Instance.new("ScrollingFrame")
VisualsPage.Size = UDim2.new(1, 0, 1, 0)
VisualsPage.BackgroundTransparency = 1
VisualsPage.BorderSizePixel = 0
VisualsPage.CanvasSize = UDim2.new(0, 0, 0, 320)
VisualsPage.ScrollBarThickness = 2
VisualsPage.ScrollBarImageColor3 = Color3.fromRGB(0, 120, 255)
VisualsPage.Visible = true
VisualsPage.Parent = PagesContainer

local SettingsPage = Instance.new("ScrollingFrame")
SettingsPage.Size = UDim2.new(1, 0, 1, 0)
SettingsPage.BackgroundTransparency = 1
SettingsPage.BorderSizePixel = 0
SettingsPage.CanvasSize = UDim2.new(0, 0, 0, 320)
SettingsPage.ScrollBarThickness = 2
SettingsPage.ScrollBarImageColor3 = Color3.fromRGB(0, 120, 255)
SettingsPage.Visible = false
SettingsPage.Parent = PagesContainer

local function createPageLayout(parentPage)
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = parentPage
end

createPageLayout(VisualsPage)
createPageLayout(SettingsPage)

-- Tab Switching with Animations
local function createTabButton(name, targetPage)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 145, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(14, 22, 36)
    btn.TextColor3 = Color3.fromRGB(160, 180, 205)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamMedium
    btn.Text = name
    btn.Parent = TabBar
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(25, 40, 65)
    stroke.Thickness = 1
    stroke.Parent = btn

    btn.MouseButton1Click:Connect(function()
        VisualsPage.Visible = false
        SettingsPage.Visible = false
        targetPage.Visible = true
        
        for _, child in ipairs(TabBar:GetChildren()) do
            if child:IsA("TextButton") then
                TweenService:Create(child, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(14, 22, 36), TextColor3 = Color3.fromRGB(160, 180, 205)}):Play()
            end
        end
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 110, 220), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)
    
    return btn
end

local tab1 = createTabButton("Visuals", VisualsPage)
tab1.BackgroundColor3 = Color3.fromRGB(0, 110, 220)
tab1.TextColor3 = Color3.fromRGB(255, 255, 255)
createTabButton("Settings", SettingsPage)

-- UI Toggle Animation Function
local uiVisible = true
local function toggleUI()
    uiVisible = not uiVisible
    if uiVisible then
        MainContainer.Visible = true
        TweenService:Create(MainContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
    else
        local tw = TweenService:Create(MainContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1})
        tw:Play()
        tw.Completed:Connect(function()
            if not uiVisible then MainContainer.Visible = false end
        end)
    end
end

OpenButton.MouseButton1Click:Connect(toggleUI)

-- Keyboard Toggle Listener (Editable Keybind)
connections.keybind = UserInputService.InputBegan:Connect(function(input, gpe)
    if waitingForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            toggleKey = input.KeyCode
            waitingForKey = false
            -- Find keybind button text and update it
            for _, child in ipairs(SettingsPage:GetChildren()) do
                if child:IsA("TextButton") and child.Name == "KeybindButton" then
                    child.Text = "Toggle Menu Key: [" .. tostring(toggleKey.Name) .. "]"
                end
            end
        end
        return
    end
    
    if not gpe and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == toggleKey then
        toggleUI()
    end
end)

-- Component Builders
local function createToggle(parent, name, callback)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, 0, 0, 40)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(14, 20, 32)
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
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
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(12, 30, 55)}):Play()
            stroke.Color = Color3.fromRGB(0, 130, 255)
            statusDot.BackgroundColor3 = Color3.fromRGB(0, 210, 255)
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(14, 20, 32)}):Play()
            stroke.Color = Color3.fromRGB(22, 32, 50)
            statusDot.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
            label.TextColor3 = Color3.fromRGB(180, 200, 225)
        end
        callback(state)
    end)
end

local function createButton(parent, name, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = color
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.Name = name == "Toggle Menu Key: [K]" and "KeybindButton" or "CustomBtn"
    btn.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- ═══ POPULATE VISUALS TAB ═══
createToggle(VisualsPage, "ESP Outline", function(v)
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

createToggle(VisualsPage, "Box ESP", function(v)
    boxEnabled = v
end)

createToggle(VisualsPage, "Tracers", function(v)
    tracersEnabled = v
end)

createToggle(VisualsPage, "Distance Indicator", function(v)
    distanceEnabled = v
end)

createToggle(VisualsPage, "Team Check (Ignore Teammates)", function(v)
    teamCheckEnabled = v
end)

createButton(VisualsPage, "Cycle Theme Color", Color3.fromRGB(18, 30, 52), function()
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

-- ═══ POPULATE SETTINGS TAB ═══
createToggle(SettingsPage, "Show Mobile Open Button", function(v)
    OpenButton.Visible = v
end)

createButton(SettingsPage, "Toggle Menu Key: [K]", Color3.fromRGB(18, 30, 52), function()
    waitingForKey = true
    local btn = SettingsPage:FindFirstChild("KeybindButton")
    if btn then btn.Text = "Press any key..." end
end)

createButton(SettingsPage, "Destroy UI & Exit", Color3.fromRGB(140, 30, 40), function()
    if _G.HubCleanup then
        _G.HubCleanup()
    end
end)

-- Cleanup Handler
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

print("ZERTZ ESP V3 (Animated & Keybind Editable) Loaded Successfully!")
