-- ============================================
-- ZERTZ ESP - Clean Visuals (STABLE)
-- ============================================

if _G.HubCleanup then _G.HubCleanup() end

-- Try multiple Rayfield sources
local Rayfield = nil
local success = false

pcall(function()
    Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    success = true
end)

if not success then
    pcall(function()
        Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()
        success = true
    end)
end

if not success or not Rayfield then
    Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

-- ═══ STATE CONFIG ═══
local espEnabled = false
local tracersEnabled = false
local distanceEnabled = false
local currentESPColor = Color3.fromRGB(255, 50, 50)

local espObjects = {}
local connections = {}

-- ═══ UTILITY ═══
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
    
    -- Highlight (Outline)
    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 0.85
    highlight.OutlineTransparency = 0
    highlight.FillColor = currentESPColor
    highlight.OutlineColor = currentESPColor
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    -- Tracer Line
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Color = currentESPColor
    tracer.Transparency = 0.7
    tracer.Visible = false
    
    -- Distance Text
    local text = Drawing.new("Text")
    text.Size = 13
    text.Center = true
    text.Outline = true
    text.Color = currentESPColor
    text.Visible = false
    
    espObjects[target] = {
        Highlight = highlight,
        Tracer = tracer,
        Text = text
    }
end

local function removeESP(target)
    local data = espObjects[target]
    if data then
        if data.Highlight then data.Highlight:Destroy() end
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
                    -- Highlight Toggle Control
                    if espEnabled then
                        data.Highlight.Parent = char
                    else
                        data.Highlight.Parent = nil
                    end
                    
                    -- Screen Position Check
                    local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                    
                    -- Tracers
                    if tracersEnabled and onScreen and espEnabled then
                        data.Tracer.From = bottomCenter
                        data.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        data.Tracer.Visible = true
                    else
                        data.Tracer.Visible = false
                    end
                    
                    -- Distance
                    if distanceEnabled and onScreen and espEnabled and LocalPlayer.Character then
                        local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if localRoot then
                            local distance = math.floor((localRoot.Position - rootPart.Position).Magnitude)
                            data.Text.Text = distance .. " studs"
                            data.Text.Position = Vector2.new(screenPos.X, screenPos.Y + 15)
                            data.Text.Visible = true
                        else
                            data.Text.Visible = false
                        end
                    else
                        data.Text.Visible = false
                    end
                else
                    data.Highlight.Parent = nil
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

-- ═══ CREATE UI ═══
local Window = nil
local createSuccess = pcall(function()
    Window = Rayfield:CreateWindow({
        Name = "ZERTZ ESP",
        LoadingTitle = "ZERTZ ESP",
        LoadingSubtitle = "Initializing...",
        Theme = "Default",
        ConfigurationSaving = { Enabled = false },
        Discord = { Enabled = false },
        KeySystem = false
    })
end)

if not createSuccess or not Window then
    error("Failed to create UI window")
    return
end

-- Visuals Tab
local VisualsTab = Window:CreateTab("Visuals", 4483362458)

VisualsTab:CreateToggle({
    Name = "ESP Outline",
    CurrentValue = false,
    Flag = "ESP",
    Callback = function(v)
        espEnabled = v
        if not v then
            for _, data in pairs(espObjects) do
                if data.Highlight then data.Highlight.Parent = nil end
                if data.Tracer then data.Tracer.Visible = false end
                if data.Text then data.Text.Visible = false end
            end
        end
    end
})

VisualsTab:CreateToggle({
    Name = "Tracers",
    CurrentValue = false,
    Flag = "Tracers",
    Callback = function(v)
        tracersEnabled = v
    end
})

VisualsTab:CreateToggle({
    Name = "Distance Indicator",
    CurrentValue = false,
    Flag = "Distance",
    Callback = function(v)
        distanceEnabled = v
    end
})

VisualsTab:CreateColorPicker({
    Name = "ESP Color Theme",
    Color = Color3.fromRGB(255, 50, 50),
    Flag = "Color",
    Callback = function(v)
        currentESPColor = v
        for _, data in pairs(espObjects) do
            if data.Highlight then
                data.Highlight.FillColor = v
                data.Highlight.OutlineColor = v
            end
            if data.Tracer then data.Tracer.Color = v end
            if data.Text then data.Text.Color = v end
        end
    end
})

-- Settings Tab (Destroy UI)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateButton({
    Name = "Destroy UI & Revert All",
    Callback = function()
        if _G.HubCleanup then
            _G.HubCleanup()
        end
    end
})

Rayfield:Notify({
   Title = "ZERTZ ESP Loaded!",
   Content = "Clean Visuals, Tracers & Distance active.",
   Duration = 5,
})

-- Cleanup Function Definition
_G.HubCleanup = function()
    for _, c in pairs(connections) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    connections = {}
    for p, _ in pairs(espObjects) do
        removeESP(p)
    end
    espObjects = {}
    if Rayfield and Rayfield.Destroy then
        pcall(function() Rayfield:Destroy() end)
    end
    _G.HubCleanup = nil
end
