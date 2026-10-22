-- ============================================
-- ZERTZ ESP, MOVEMENT & RIVALS HUB (V10)
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
-- Visuals State
local espEnabled = false
local boxEnabled = false
local tracersEnabled = false
local distanceEnabled = false
local teamCheckEnabled = false

-- Movement State
local speedEnabled = false
local speedValue = 32
local infJumpEnabled = false
local spinbotEnabled = false
local flyEnabled = false
local flySpeed = 50

-- Rivals State
local killEffectsEnabled = false

-- Settings State
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

-- ═══ RIVALS FEATURES ═══
local function randomizeWeaponSkins()
    pcall(function()
        local weaponModels = LocalPlayer.PlayerScripts.Assets.ViewModels.Weapons:GetChildren()
        local mats = Enum.Material:GetEnumItems()
        for _, model in ipairs(weaponModels) do
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency ~= 1 then
                    part.Color = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
                    part.Material = mats[math.random(#mats)]
                end
            end
        end
    end)
end

-- ═══ MOVEMENT LOGIC ═══
connections.infJump = UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

connections.physics = RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not hum or not root then return end

    if speedEnabled and hum then
        hum.WalkSpeed = speedValue
    end

    if spinbotEnabled and root then
        root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(50), 0)
    end

    if flyEnabled and root then
        local moveDir = hum.MoveDirection
        local flyVel = Vector3.zero
        
        if moveDir.Magnitude > 0 then
            flyVel = moveDir * flySpeed
        end
        
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            flyVel = flyVel + Vector3.new(0, flySpeed, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            flyVel = flyVel - Vector3.new(0, flySpeed, 0)
        end

        root.AssemblyLinearVelocity = flyVel
    end
end)

local function updateSpeedState(v)
    speedEnabled = v
    if not v and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end
end

-- ═══ RENDER LOOP (RIVALS-FIXED FEET-TO-HEAD BOX) ═══
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
                        if boxEnabled and espEnabled then
                            local head = char:FindFirstChild("Head")
                            if head then
                                local headScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.7, 0))
                                local feetScreen = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3.2, 0))
                                
                                local height = math.abs(headScreen.Y - feetScreen.Y)
                                local width = height / 1.8
                                
                                data.Box.Size = Vector2.new(width, height)
                                data.Box.Position = Vector2.new(headScreen.X - (width / 2), headScreen.Y)
                                data.Box.Visible = true
                            else
                                data.Box.Visible = false
                            end
                        else
                            data.Box.Visible = false
                        end

                        if tracersEnabled and espEnabled then
                            local feetWorld = rootPart.Position - Vector3.new(0, 3.2, 0)
                            local feetScreen = Camera:WorldToViewportPoint(feetWorld)
                            
                            data.Tracer.From = bottomCenter
                            data.Tracer.To = Vector2.new(feetScreen.X, feetScreen.Y)
                            data.Tracer.Visible = true
                        else
                            data.Tracer.Visible = false
                        end
                        
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

-- ═══ UI CREATION (APOLLO STYLE HUB) ═══
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZertzESP_ApolloHubV10"
ScreenGui.ResetOnSpawn = false

pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

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

-- Floating Open Button
local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.new(0, 44, 0, 44)
OpenButton.Position = UDim2.new(0, 20, 0, 160)
OpenButton.BackgroundColor3 = Color3.fromRGB(12, 15, 24)
OpenButton.TextColor3 = Color3.fromRGB(0, 190, 255)
OpenButton.TextSize = 18
OpenButton.Font = Enum.Font.GothamBold
OpenButton.Text = "Z"
OpenButton.Parent = ScreenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(0, 10)
OpenCorner.Parent = OpenButton

local OpenStroke = Instance.new("UIStroke")
OpenStroke.Color = Color3.fromRGB(35, 55, 90)
OpenStroke.Thickness = 1.2
OpenStroke.Parent = OpenButton

makeDraggable(OpenButton)

-- Main Container Frame
local MainContainer = Instance.new("CanvasGroup")
MainContainer.Name = "MainContainer"
MainContainer.Size = UDim2.new(0, 400, 0, 430)
MainContainer.Position = UDim2.new(0.5, -200, 0.5, -215)
MainContainer.BackgroundTransparency = 1
MainContainer.GroupTransparency = 0
MainContainer.Visible = true
MainContainer.Parent = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(1, 0, 1, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(9, 12, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = MainContainer

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(30, 45, 75)
MainStroke.Thickness = 1.2
MainStroke.Parent = MainContainer

-- Top Bar Header
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 45)
TopBar.BackgroundColor3 = Color3.fromRGB(13, 17, 26)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = TopBar

local TopCover = Instance.new("Frame")
TopCover.Size = UDim2.new(1, 0, 0, 10)
TopCover.Position = UDim2.new(0, 0, 1, -10)
TopCover.BackgroundColor3 = Color3.fromRGB(13, 17, 26)
TopCover.BorderSizePixel = 0
TopCover.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "ZERTZ  //  RIVALS & ESP HUB"
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

makeDraggable(MainContainer, TopBar)

-- Tab Bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -24, 0, 36)
TabBar.Position = UDim2.new(0, 12, 0, 54)
TabBar.BackgroundColor3 = Color3.fromRGB(11, 15, 23)
TabBar.Parent = MainFrame

local TabBarCorner = Instance.new("UICorner")
TabBarCorner.CornerRadius = UDim.new(0, 8)
TabBarCorner.Parent = TabBar

local TabBarStroke = Instance.new("UIStroke")
TabBarStroke.Color = Color3.fromRGB(22, 33, 54)
TabBarStroke.Thickness = 1
TabBarStroke.Parent = TabBar

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabListLayout.Padding = UDim.new(0, 0)
TabListLayout.Parent = TabBar

-- Pages Container
local PagesContainer = Instance.new("Frame")
PagesContainer.Size = UDim2.new(1, -24, 1, -112)
PagesContainer.Position = UDim2.new(0, 12, 0, 102)
PagesContainer.BackgroundTransparency = 1
PagesContainer.Parent = MainFrame

local VisualsPage = Instance.new("ScrollingFrame")
VisualsPage.Size = UDim2.new(1, 0, 1, 0)
VisualsPage.BackgroundTransparency = 1
VisualsPage.BorderSizePixel = 0
VisualsPage.CanvasSize = UDim2.new(0, 0, 0, 320)
VisualsPage.ScrollBarThickness = 2
VisualsPage.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
VisualsPage.Visible = true
VisualsPage.Parent = PagesContainer

local MovementPage = Instance.new("ScrollingFrame")
MovementPage.Size = UDim2.new(1, 0, 1, 0)
MovementPage.BackgroundTransparency = 1
MovementPage.BorderSizePixel = 0
MovementPage.CanvasSize = UDim2.new(0, 0, 0, 320)
MovementPage.ScrollBarThickness = 2
MovementPage.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
MovementPage.Visible = false
MovementPage.Parent = PagesContainer

local RivalsPage = Instance.new("ScrollingFrame")
RivalsPage.Size = UDim2.new(1, 0, 1, 0)
RivalsPage.BackgroundTransparency = 1
RivalsPage.BorderSizePixel = 0
RivalsPage.CanvasSize = UDim2.new(0, 0, 0, 300)
RivalsPage.ScrollBarThickness = 2
RivalsPage.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
RivalsPage.Visible = false
RivalsPage.Parent = PagesContainer

local SettingsPage = Instance.new("ScrollingFrame")
SettingsPage.Size = UDim2.new(1, 0, 1, 0)
SettingsPage.BackgroundTransparency = 1
SettingsPage.BorderSizePixel = 0
SettingsPage.CanvasSize = UDim2.new(0, 0, 0, 260)
SettingsPage.ScrollBarThickness = 2
SettingsPage.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
SettingsPage.Visible = false
SettingsPage.Parent = PagesContainer

local function createPageLayout(parentPage)
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = parentPage
end

createPageLayout(VisualsPage)
createPageLayout(MovementPage)
createPageLayout(RivalsPage)
createPageLayout(SettingsPage)

-- Tab Switcher Builder (4 Tabs)
local function createTabButton(name, targetPage)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.25, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.TextColor3 = Color3.fromRGB(130, 150, 180)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamMedium
    btn.Text = name
    btn.Parent = TabBar

    btn.MouseButton1Click:Connect(function()
        VisualsPage.Visible = false
        MovementPage.Visible = false
        RivalsPage.Visible = false
        SettingsPage.Visible = false
        targetPage.Visible = true
        
        for _, child in ipairs(TabBar:GetChildren()) do
            if child:IsA("TextButton") then
                TweenService:Create(child, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(130, 150, 180)}):Play()
            end
        end
        TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)
    
    return btn
end

local tab1 = createTabButton("Visuals", VisualsPage)
tab1.TextColor3 = Color3.fromRGB(255, 255, 255)
createTabButton("Movement", MovementPage)
createTabButton("Rivals", RivalsPage)
createTabButton("Settings", SettingsPage)

-- UI Toggle
local uiVisible = true
local function toggleUI()
    uiVisible = not uiVisible
    if uiVisible then
        MainContainer.Visible = true
        TweenService:Create(MainContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
    else
        local tw = TweenService:Create(MainContainer, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1})
        tw:Play()
        tw.Completed:Connect(function()
            if not uiVisible then MainContainer.Visible = false end
        end)
    end
end

OpenButton.MouseButton1Click:Connect(toggleUI)

connections.keybind = UserInputService.InputBegan:Connect(function(input, gpe)
    if waitingForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            toggleKey = input.KeyCode
            waitingForKey = false
            for _, child in ipairs(SettingsPage:GetChildren()) do
                if child:IsA("TextButton") and child.Name == "KeybindButton" then
                    child.Text = "Menu Keybind: [" .. tostring(toggleKey.Name) .. "]"
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
    toggleBtn.Size = UDim2.new(1, 0, 0, 38)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(13, 17, 26)
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = toggleBtn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(22, 31, 48)
    stroke.Thickness = 1
    stroke.Parent = toggleBtn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(175, 195, 220)
    label.TextSize = 12
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggleBtn

    local switchBg = Instance.new("Frame")
    switchBg.Size = UDim2.new(0, 36, 0, 18)
    switchBg.Position = UDim2.new(1, -46, 0.5, -9)
    switchBg.BackgroundColor3 = Color3.fromRGB(22, 30, 46)
    switchBg.BorderSizePixel = 0
    switchBg.Parent = toggleBtn

    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switchBg

    local switchKnob = Instance.new("Frame")
    switchKnob.Size = UDim2.new(0, 14, 0, 14)
    switchKnob.Position = UDim2.new(0, 2, 0.5, -7)
    switchKnob.BackgroundColor3 = Color3.fromRGB(120, 140, 170)
    switchKnob.BorderSizePixel = 0
    switchKnob.Parent = switchBg

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = switchKnob

    local state = false
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            TweenService:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 130, 255)}):Play()
            TweenService:Create(switchKnob, TweenInfo.new(0.2), {Position = UDim2.new(1, -16, 0.5, -7), BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(12, 24, 44)}):Play()
            stroke.Color = Color3.fromRGB(0, 110, 220)
            label.TextColor3 = Color3.fromRGB(240, 245, 255)
        else
            TweenService:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(22, 30, 46)}):Play()
            TweenService:Create(switchKnob, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = Color3.fromRGB(120, 140, 170)}):Play()
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(13, 17, 26)}):Play()
            stroke.Color = Color3.fromRGB(22, 31, 48)
            label.TextColor3 = Color3.fromRGB(175, 195, 220)
        end
        callback(state)
    end)
end

local function createInputSlider(parent, title, defaultVal, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 38)
    frame.BackgroundColor3 = Color3.fromRGB(13, 17, 26)
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(22, 31, 48)
    stroke.Thickness = 1
    stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Color3.fromRGB(175, 195, 220)
    label.TextSize = 12
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 54, 0, 24)
    box.Position = UDim2.new(1, -62, 0.5, -12)
    box.BackgroundColor3 = Color3.fromRGB(8, 11, 17)
    box.TextColor3 = Color3.fromRGB(0, 170, 255)
    box.TextSize = 12
    box.Font = Enum.Font.GothamBold
    box.Text = tostring(defaultVal)
    box.Parent = frame

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 5)
    boxCorner.Parent = box

    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num then
            callback(num)
        else
            box.Text = tostring(defaultVal)
        end
    end)
end

local function createButton(parent, name, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = color
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Name = name:find("Keybind") and "KeybindButton" or "CustomBtn"
    btn.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = btn
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function createButtonWithSubtext(parent, mainText, subtext, color, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 48)
    container.BackgroundColor3 = color
    container.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = container

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 130, 255)
    stroke.Thickness = 1
    stroke.Parent = container

    local mainLabel = Instance.new("TextLabel")
    mainLabel.Size = UDim2.new(1, 0, 0, 24)
    mainLabel.Position = UDim2.new(0, 0, 0, 4)
    mainLabel.BackgroundTransparency = 1
    mainLabel.Text = mainText
    mainLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    mainLabel.TextSize = 13
    mainLabel.Font = Enum.Font.GothamBold
    mainLabel.Parent = container

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, 0, 0, 16)
    subLabel.Position = UDim2.new(0, 0, 0, 26)
    subLabel.BackgroundTransparency = 1
    subLabel.Text = subtext
    subLabel.TextColor3 = Color3.fromRGB(140, 170, 210)
    subLabel.TextSize = 10
    subLabel.Font = Enum.Font.GothamMedium
    subLabel.Parent = container

    local clickBtn = Instance.new("TextButton")
    clickBtn.Size = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""
    clickBtn.Parent = container

    clickBtn.MouseButton1Click:Connect(callback)
    return container
end

-- ═══ POPULATE TABS ═══
-- Visuals Tab
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

createToggle(VisualsPage, "Team Check", function(v)
    teamCheckEnabled = v
end)

createButton(VisualsPage, "Cycle Theme Color", Color3.fromRGB(16, 26, 45), function()
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

-- Movement Tab
createToggle(MovementPage, "WalkSpeed Toggle", function(v)
    updateSpeedState(v)
end)

createInputSlider(MovementPage, "WalkSpeed Value", 32, function(v)
    speedValue = v
end)

createToggle(MovementPage, "Infinite Jump", function(v)
    infJumpEnabled = v
end)

createToggle(MovementPage, "Spinbot", function(v)
    spinbotEnabled = v
end)

createToggle(MovementPage, "Fly Toggle", function(v)
    flyEnabled = v
    if not v and LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then root.AssemblyLinearVelocity = Vector3.zero end
    end
end)

createInputSlider(MovementPage, "Fly Speed", 50, function(v)
    flySpeed = v
end)

-- Rivals Tab (Warning, standard options first, then External Loader at the very bottom)
local warningLabel = Instance.new("TextLabel")
warningLabel.Size = UDim2.new(1, 0, 0, 36)
warningLabel.BackgroundColor3 = Color3.fromRGB(45, 20, 20)
warningLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
warningLabel.TextSize = 10
warningLabel.Font = Enum.Font.GothamBold
warningLabel.Text = "⚠️ KILL EFFECTS MIGHT BUG OUT WEAPON USE WITH CAUTION"
warningLabel.TextWrapped = true
warningLabel.Parent = RivalsPage

local warnCorner = Instance.new("UICorner")
warnCorner.CornerRadius = UDim.new(0, 6)
warnCorner.Parent = warningLabel

local warnStroke = Instance.new("UIStroke")
warnStroke.Color = Color3.fromRGB(180, 40, 40)
warnStroke.Thickness = 1
warnStroke.Parent = warningLabel

createToggle(RivalsPage, "Kill Effects (Caution)", function(v)
    killEffectsEnabled = v
end)

createButton(RivalsPage, "Randomize Weapon Skins", Color3.fromRGB(16, 26, 45), function()
    randomizeWeaponSkins()
end)

-- Load External UI at the very bottom as a last resort option
createButtonWithSubtext(
    RivalsPage,
    "LOAD EXTERNAL UI",
    "loads Apollo Changer v1.8.4",
    Color3.fromRGB(16, 32, 58),
    function()
        pcall(function()
            loadstring(game:HttpGet('https://raw.githubusercontent.com/apolloskinchanger/apollochanger/main/apollochangerv1.8.4.lua'))()
        end)
    end
)

-- Settings Tab
createToggle(SettingsPage, "Show Mobile Open Button", function(v)
    OpenButton.Visible = v
end)

createButton(SettingsPage, "Menu Keybind: [K]", Color3.fromRGB(16, 26, 45), function()
    waitingForKey = true
    local btn = SettingsPage:FindFirstChild("KeybindButton")
    if btn then btn.Text = "Press any key..." end
end)

createButton(SettingsPage, "Destroy UI & Exit", Color3.fromRGB(130, 30, 40), function()
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
    updateSpeedState(false)
    if ScreenGui then
        ScreenGui:Destroy()
    end
    _G.HubCleanup = nil
end

print("ZERTZ ESP V10 Loaded Successfully!")
