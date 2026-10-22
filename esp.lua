-- ============================================
-- ZERTZ ESP - 100% Custom Dark Blue UI (Mobile & PC)
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
local currentESPColor = Color3.fromRGB(0, 150, 255) -- Bright Blue accent

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
    tracer.Thickness = 1
    tracer.Color = currentESPColor
    tracer.Transparency = 0.7
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
                        -- Box ESP (Feet to Head bounds)
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

-- ═══ CUSTOM UI CREATION (DARK BLUE & MOBILE FRIENDLY) ═══
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZertzESPCustom"
ScreenGui.ResetOnSpawn = false
pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Floating Mobile Open/Close Button (Draggable / Tap)
local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.new(0, 45, 0, 45)
OpenButton.Position = UDim2.new(0, 20, 0, 150)
OpenButton.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
OpenButton.BorderColor3 = Color3.fromRGB(0, 120, 255)
OpenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenButton.TextSize = 16
OpenButton.Font = Enum.Font.GothamBold
OpenButton.Text = "Z"
OpenButton.Parent = ScreenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(0, 10)
OpenCorner.Parent = OpenButton

-- Main Window Frame (Dark Blue Theme)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 340)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -170)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

-- Top Bar (Draggable for Mobile & PC)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = TopBar

local TopCover = Instance.new("Frame")
TopCover.Size = UDim2.new(1, 0, 0, 10)
TopCover.Position = UDim2.new(0, 0, 1, -10)
TopCover.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
TopCover.BorderSizePixel = 0
TopCover.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Color3.fromRGB(220, 240, 255)
TitleLabel.TextSize = 15
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "ZERTZ ESP"
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

-- Content Layout
local ContentContainer = Instance.new("ScrollingFrame")
ContentContainer.Size = UDim2.new(1, -20, 1, -55)
ContentContainer.Position = UDim2.new(0, 10, 0, 48)
ContentContainer.BackgroundTransparency = 1
ContentContainer.BorderSizePixel = 0
ContentContainer.CanvasSize = UDim2.new(0, 0, 0, 280)
ContentContainer.ScrollBarThickness = 3
ContentContainer.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 8)
UIList.Parent = ContentContainer

-- Toggle Builder
local function createToggle(name, callback)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, 0, 0, 40)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(18, 26, 42)
    toggleBtn.TextColor3 = Color3.fromRGB(190, 210, 235)
    toggleBtn.TextSize = 14
    toggleBtn.Font = Enum.Font.GothamMedium
    toggleBtn.Text = "  " .. name .. ": OFF"
    toggleBtn.TextXAlignment = Enum.TextXAlignment.Left
    toggleBtn.Parent = ContentContainer
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = toggleBtn
    
    local state = false
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 220)
            toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            toggleBtn.Text = "  " .. name .. ": ON"
        else
            toggleBtn.BackgroundColor3 = Color3.fromRGB(18, 26, 42)
            toggleBtn.TextColor3 = Color3.fromRGB(190, 210, 235)
            toggleBtn.Text = "  " .. name .. ": OFF"
        end
        callback(state)
    end)
end

-- Button Builder
local function createButton(name, buttonColor, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = buttonColor
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.Text = name
    btn.Parent = ContentContainer
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    
    btn.MouseButton1Click:Connect(callback)
end

-- Build Controls
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

createButton("Destroy UI & Exit", Color3.fromRGB(160, 35, 35), function()
    if _G.HubCleanup then
        _G.HubCleanup()
    end
end)

-- Toggle Menu Visibility via Floating 'Z' Button
OpenButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Make Window Draggable (Supports Mobile Touch and Mouse Dragging)
local dragging, dragInput, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
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
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Cleanup / Destroy Function
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

print("ZERTZ ESP Custom Dark Blue UI Loaded Successfully!")
