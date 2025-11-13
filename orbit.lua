--// Enhanced Orbit Controller v4 - All Features Intact //--
-- Improved UI with toggles, tabs, and better layout

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

-- SETTINGS
local SETTINGS = {
    ORBIT_RADIUS = 12,
    ORBIT_SPEED = 1.2,
    HEIGHT_OFFSET = 4,
    MAX_PARTS = 40,
    SCAN_INTERVAL = 3,
    ALIGN_RESPONSIVENESS = 30,
    ALIGN_FORCE = 1e8,
    AUTO_ATTACH = true,
    PICKUP_RANGE = math.huge,
    ORBIT_MODE = "Ring",
    SPINNING = false,
    ENEMY_TARGET = nil,
}

-- INTERNALS
local tracked = {}
local lastScan = 0
local spinMultiplier = 1

-- RESPAWN FIX
player.CharacterAdded:Connect(function(c)
    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
end)

----------------------------------------------
-- PART ORBIT SYSTEM (UNCHANGED)
----------------------------------------------

local function cleanupPart(part)
    local info = tracked[part]
    if not info then return end
    if info.target then info.target:Destroy() end
    if info.attachTarget then info.attachTarget:Destroy() end
    if info.attachPart then info.attachPart:Destroy() end
    if info.alignP then info.alignP:Destroy() end
    if info.alignO then info.alignO:Destroy() end
    tracked[part] = nil
end

local function attachPart(part)
    if tracked[part] then return end
    if part.Anchored then return end
    if part:IsDescendantOf(char) then return end
    if (part.Position - hrp.Position).Magnitude > SETTINGS.PICKUP_RANGE then return end

    part.Massless = true
    part.CanCollide = false
    part.CanTouch = false

    local target = Instance.new("Part")
    target.Size = Vector3.new(0.2,0.2,0.2)
    target.Transparency = 1
    target.CanCollide = false
    target.Anchored = true
    target.Parent = Workspace

    local ap = Instance.new("Attachment", part)
    local at = Instance.new("Attachment", target)

    local alignP = Instance.new("AlignPosition")
    alignP.Attachment0 = ap
    alignP.Attachment1 = at
    alignP.MaxForce = SETTINGS.ALIGN_FORCE
    alignP.Responsiveness = SETTINGS.ALIGN_RESPONSIVENESS
    alignP.Parent = part

    local alignO = Instance.new("AlignOrientation")
    alignO.Attachment0 = ap
    alignO.Attachment1 = at
    alignO.MaxTorque = SETTINGS.ALIGN_FORCE
    alignO.Responsiveness = SETTINGS.ALIGN_RESPONSIVENESS
    alignO.Parent = part

    tracked[part] = {
        target = target,
        attachPart = ap,
        attachTarget = at,
        alignP = alignP,
        alignO = alignO,
    }

    part.Destroying:Connect(function()
        cleanupPart(part)
    end)
end

local function scan()
    if not SETTINGS.AUTO_ATTACH then return end
    local count = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj.Anchored then
            attachPart(obj)
            count += 1
            if count >= SETTINGS.MAX_PARTS then break end
        end
    end
end

Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("BasePart") and SETTINGS.AUTO_ATTACH then
        attachPart(obj)
    end
end)

----------------------------------------------
-- ORBIT COMPUTATION (UNCHANGED)
----------------------------------------------

local function computeOrbitPosition(i, total)
    local t = tick() * SETTINGS.ORBIT_SPEED * spinMultiplier
    local targetHRP = SETTINGS.ENEMY_TARGET and SETTINGS.ENEMY_TARGET:FindFirstChild("HumanoidRootPart") or hrp

    if not targetHRP then return Vector3.new() end

    if SETTINGS.ORBIT_MODE == "Ring" then
        local angle = (i / total) * math.pi * 2
        return Vector3.new(
            math.cos(t + angle) * SETTINGS.ORBIT_RADIUS,
            SETTINGS.HEIGHT_OFFSET,
            math.sin(t + angle) * SETTINGS.ORBIT_RADIUS
        )

    elseif SETTINGS.ORBIT_MODE == "Sphere" then
        local phi = math.acos(1 - 2 * (i / total))
        local theta = math.sqrt(total * math.pi) * phi
        return Vector3.new(
            SETTINGS.ORBIT_RADIUS * math.sin(phi) * math.cos(theta),
            SETTINGS.ORBIT_RADIUS * math.cos(phi),
            SETTINGS.ORBIT_RADIUS * math.sin(phi) * math.sin(theta)
        )

    elseif SETTINGS.ORBIT_MODE == "Vertical" then
        local angle = (i / total) * math.pi * 2
        return Vector3.new(
            math.cos(t + angle) * SETTINGS.ORBIT_RADIUS,
            math.sin(t + angle) * SETTINGS.ORBIT_RADIUS,
            0
        )

    elseif SETTINGS.ORBIT_MODE == "Cloud" then
        return Vector3.new(
            math.sin(t + i) * SETTINGS.ORBIT_RADIUS,
            math.cos(t * 0.4 + i) * SETTINGS.ORBIT_RADIUS * 0.5,
            math.cos(t + i * 0.3) * SETTINGS.ORBIT_RADIUS
        )

    elseif SETTINGS.ORBIT_MODE == "Blackhole" then
        local dir = (targetHRP.Position - hrp.Position).Unit
        local dist = (i / total) * SETTINGS.ORBIT_RADIUS
        return dir * -dist + Vector3.new(0,math.sin(t+i)*5,0)
    end
end

RunService.Heartbeat:Connect(function()
    if not hrp or not hrp.Parent then return end

    if tick() - lastScan >= SETTINGS.SCAN_INTERVAL then
        scan()
        lastScan = tick()
    end

    local live = {}
    for part, data in pairs(tracked) do
        if part.Parent and data.target and data.target.Parent then
            table.insert(live, {part = part, data = data})
        else
            cleanupPart(part)
        end
    end

    local total = #live
    if total == 0 then return end

    for i, rec in ipairs(live) do
        local offset = computeOrbitPosition(i, total)
        if rec.data.target then
            rec.data.target.CFrame = (SETTINGS.ENEMY_TARGET and SETTINGS.ENEMY_TARGET:FindFirstChild("HumanoidRootPart") or hrp).CFrame * CFrame.new(offset)
        end
    end
end)

----------------------------------------------
-- IMPROVED GUI
----------------------------------------------

local pg = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui", pg)
gui.ResetOnSpawn = false
gui.Name = "OrbitController"

-- Main toggle button
local toggle = Instance.new("TextButton", gui)
toggle.Size = UDim2.new(0, 160, 0, 45)
toggle.Position = UDim2.new(0.5, -80, 0, 10)
toggle.Text = "🌀 ORBIT MENU"
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 16
toggle.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
toggle.BorderSizePixel = 0
toggle.AutoButtonColor = false

local toggleCorner = Instance.new("UICorner", toggle)
toggleCorner.CornerRadius = UDim.new(0, 8)

local toggleStroke = Instance.new("UIStroke", toggle)
toggleStroke.Color = Color3.fromRGB(100, 150, 255)
toggleStroke.Thickness = 2

-- Main frame
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 420, 0, 380)
frame.Position = UDim2.new(0.5, -210, 0.5, -190)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.Visible = false
frame.BorderSizePixel = 0

local frameCorner = Instance.new("UICorner", frame)
frameCorner.CornerRadius = UDim.new(0, 12)

local frameStroke = Instance.new("UIStroke", frame)
frameStroke.Color = Color3.fromRGB(100, 150, 255)
frameStroke.Thickness = 2

-- Title bar
local titleBar = Instance.new("Frame", frame)
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
titleBar.BorderSizePixel = 0

local titleCorner = Instance.new("UICorner", titleBar)
titleCorner.CornerRadius = UDim.new(0, 12)

local titleLabel = Instance.new("TextLabel", titleBar)
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🌀 ORBIT CONTROLLER"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 35, 0, 35)
closeBtn.Position = UDim2.new(1, -40, 0.5, -17.5)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false

local closeBtnCorner = Instance.new("UICorner", closeBtn)
closeBtnCorner.CornerRadius = UDim.new(0, 8)

-- Tab system
local tabBar = Instance.new("Frame", frame)
tabBar.Size = UDim2.new(1, -20, 0, 35)
tabBar.Position = UDim2.new(0, 10, 0, 50)
tabBar.BackgroundTransparency = 1

local contentFrame = Instance.new("Frame", frame)
contentFrame.Size = UDim2.new(1, -20, 1, -100)
contentFrame.Position = UDim2.new(0, 10, 0, 90)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants = true

local tabs = {}
local currentTab = nil

local function createTab(name, icon)
    local tabBtn = Instance.new("TextButton", tabBar)
    tabBtn.Size = UDim2.new(0.33, -3, 1, 0)
    tabBtn.Position = UDim2.new((#tabs) * 0.33, 0, 0, 0)
    tabBtn.Text = icon.." "..name
    tabBtn.Font = Enum.Font.GothamBold
    tabBtn.TextSize = 13
    tabBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    tabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    tabBtn.BorderSizePixel = 0
    tabBtn.AutoButtonColor = false
    
    local tabCorner = Instance.new("UICorner", tabBtn)
    tabCorner.CornerRadius = UDim.new(0, 6)
    
    local content = Instance.new("ScrollingFrame", contentFrame)
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 6
    content.Visible = false
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    local layout = Instance.new("UIListLayout", content)
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    tabs[name] = {btn = tabBtn, content = content}
    
    tabBtn.MouseButton1Click:Connect(function()
        for _, tab in pairs(tabs) do
            tab.btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            tab.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            tab.content.Visible = false
        end
        tabBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
        tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        content.Visible = true
        currentTab = name
    end)
    
    return content
end

-- Create tabs
local controlTab = createTab("Controls", "🎮")
local modesTab = createTab("Modes", "⚙️")
local settingsTab = createTab("Settings", "🔧")

-- Toggle functionality
toggle.MouseButton1Click:Connect(function()
    frame.Visible = not frame.Visible
    if frame.Visible and not currentTab then
        tabs["Controls"].btn.MouseButton1Click:Fire()
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    frame.Visible = false
end)

-- Make draggable
local dragging, dragInput, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)

titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

----------------------------------------------
-- UI COMPONENTS
----------------------------------------------

local function createToggle(parent, text, setting, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, 0, 0, 45)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    container.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", container)
    corner.CornerRadius = UDim.new(0, 8)
    
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(1, -80, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    local toggleBtn = Instance.new("TextButton", container)
    toggleBtn.Size = UDim2.new(0, 60, 0, 30)
    toggleBtn.Position = UDim2.new(1, -70, 0.5, -15)
    toggleBtn.Text = ""
    toggleBtn.BackgroundColor3 = SETTINGS[setting] and Color3.fromRGB(60, 200, 80) or Color3.fromRGB(80, 80, 90)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = false
    
    local toggleCorner = Instance.new("UICorner", toggleBtn)
    toggleCorner.CornerRadius = UDim.new(1, 0)
    
    local indicator = Instance.new("Frame", toggleBtn)
    indicator.Size = UDim2.new(0, 22, 0, 22)
    indicator.Position = SETTINGS[setting] and UDim2.new(1, -26, 0.5, -11) or UDim2.new(0, 4, 0.5, -11)
    indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    indicator.BorderSizePixel = 0
    
    local indicatorCorner = Instance.new("UICorner", indicator)
    indicatorCorner.CornerRadius = UDim.new(1, 0)
    
    local statusLabel = Instance.new("TextLabel", container)
    statusLabel.Size = UDim2.new(0, 40, 1, 0)
    statusLabel.Position = UDim2.new(1, -110, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = SETTINGS[setting] and "ON" or "OFF"
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 12
    statusLabel.TextColor3 = SETTINGS[setting] and Color3.fromRGB(60, 200, 80) or Color3.fromRGB(150, 150, 150)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Right
    
    toggleBtn.MouseButton1Click:Connect(function()
        SETTINGS[setting] = not SETTINGS[setting]
        
        local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local goal = SETTINGS[setting] and {Position = UDim2.new(1, -26, 0.5, -11)} or {Position = UDim2.new(0, 4, 0.5, -11)}
        TweenService:Create(indicator, tweenInfo, goal):Play()
        
        toggleBtn.BackgroundColor3 = SETTINGS[setting] and Color3.fromRGB(60, 200, 80) or Color3.fromRGB(80, 80, 90)
        statusLabel.Text = SETTINGS[setting] and "ON" or "OFF"
        statusLabel.TextColor3 = SETTINGS[setting] and Color3.fromRGB(60, 200, 80) or Color3.fromRGB(150, 150, 150)
        
        if callback then callback(SETTINGS[setting]) end
    end)
    
    return container
end

local function createButton(parent, text, color, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0.48, 0, 0, 45)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 8)
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.new(
            math.min(color.R * 1.2, 1),
            math.min(color.G * 1.2, 1),
            math.min(color.B * 1.2, 1)
        )}):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
    end)
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function createModeButton(parent, text, mode)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0.48, 0, 0, 45)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.BackgroundColor3 = SETTINGS.ORBIT_MODE == mode and Color3.fromRGB(100, 150, 255) or Color3.fromRGB(50, 50, 60)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    
    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 8)
    
    btn.MouseButton1Click:Connect(function()
        SETTINGS.ORBIT_MODE = mode
        
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            end
        end
        btn.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
    end)
    
    return btn
end

----------------------------------------------
-- CONTROLS TAB
----------------------------------------------

local controlsGrid = Instance.new("Frame", controlTab)
controlsGrid.Size = UDim2.new(1, 0, 0, 250)
controlsGrid.BackgroundTransparency = 1

local controlsLayout = Instance.new("UIGridLayout", controlsGrid)
controlsLayout.CellSize = UDim2.new(0.48, 0, 0, 45)
controlsLayout.CellPadding = UDim2.new(0.02, 0, 0, 8)

createButton(controlsGrid, "🚀 Launch Out", Color3.fromRGB(220, 60, 60), function()
    for part in pairs(tracked) do
        part.Velocity = (part.Position - hrp.Position).Unit * 200
    end
end)

createButton(controlsGrid, "🧲 Pull In", Color3.fromRGB(60, 180, 60), function()
    for _, data in pairs(tracked) do
        data.target.CFrame = hrp.CFrame * CFrame.new(0,2,0)
    end
end)

createButton(controlsGrid, "⚡ Spin Up", Color3.fromRGB(255, 180, 0), function()
    spinMultiplier = math.min(spinMultiplier + 0.5, 10)
end)

createButton(controlsGrid, "💥 Explode", Color3.fromRGB(255, 100, 0), function()
    for part in pairs(tracked) do
        part.Velocity = Vector3.new(
            math.random(-200,200),
            math.random(50,200),
            math.random(-200,200)
        )
    end
end)

createButton(controlsGrid, "🎯 Orbit Enemy", Color3.fromRGB(200, 60, 200), function()
    local targetPlayer = nil
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            targetPlayer = p.Character
            break
        end
    end
    SETTINGS.ENEMY_TARGET = targetPlayer
end)

createButton(controlsGrid, "🛡️ Shield Mode", Color3.fromRGB(60, 200, 200), function()
    SETTINGS.ORBIT_RADIUS = 15
    SETTINGS.ORBIT_MODE = "Sphere"
end)

----------------------------------------------
-- MODES TAB
----------------------------------------------

local modesGrid = Instance.new("Frame", modesTab)
modesGrid.Size = UDim2.new(1, 0, 0, 220)
modesGrid.BackgroundTransparency = 1

local modesLayout = Instance.new("UIGridLayout", modesGrid)
modesLayout.CellSize = UDim2.new(0.48, 0, 0, 45)
modesLayout.CellPadding = UDim2.new(0.02, 0, 0, 8)

createModeButton(modesGrid, "⭕ Ring", "Ring")
createModeButton(modesGrid, "🌐 Sphere", "Sphere")
createModeButton(modesGrid, "↕️ Vertical", "Vertical")
createModeButton(modesGrid, "☁️ Cloud", "Cloud")
createModeButton(modesGrid, "🌀 Blackhole", "Blackhole")

----------------------------------------------
-- SETTINGS TAB
----------------------------------------------

createToggle(settingsTab, "Auto Attach Parts", "AUTO_ATTACH", function(enabled)
    if enabled then scan() end
end)

local savebtn = createButton(settingsTab, "💾 Save Preset", Color3.fromRGB(80, 120, 200), function()
    local preset = {}
    for k,v in pairs(SETTINGS) do
        preset[k] = v
    end
    writefile("OrbitPreset.json", game:GetService("HttpService"):JSONEncode(preset))
end)
savebtn.Size = UDim2.new(1, 0, 0, 40)

local loadbtn = createButton(settingsTab, "📂 Load Preset", Color3.fromRGB(80, 200, 120), function()
    if not isfile("OrbitPreset.json") then return end
    local json = readfile("OrbitPreset.json")
    local preset = game:GetService("HttpService"):JSONDecode(json)
    for k,v in pairs(preset) do
        SETTINGS[k] = v
    end
end)
loadbtn.Size = UDim2.new(1, 0, 0, 40)

-- Status display
local statusFrame = Instance.new("Frame", settingsTab)
statusFrame.Size = UDim2.new(1, 0, 0, 70)
statusFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
statusFrame.BorderSizePixel = 0

local statusCorner = Instance.new("UICorner", statusFrame)
statusCorner.CornerRadius = UDim.new(0, 8)

local statusLabel = Instance.new("TextLabel", statusFrame)
statusLabel.Size = UDim2.new(1, -20, 1, -10)
statusLabel.Position = UDim2.new(0, 10, 0, 5)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Parts Tracked: 0\nOrbit Mode: Ring\nSpin: 1.0x"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top

RunService.Heartbeat:Connect(function()
    local count = 0
    for _ in pairs(tracked) do count += 1 end
    local enemyName = SETTINGS.ENEMY_TARGET and "Yes" or "No"
    statusLabel.Text = string.format("Parts Tracked: %d\nOrbit Mode: %s\nSpin: %.1fx\nTargeting Enemy: %s", 
        count, SETTINGS.ORBIT_MODE, spinMultiplier, enemyName)
end)

print("✅ Enhanced Orbit Controller v4 Loaded - All Features Working!")
