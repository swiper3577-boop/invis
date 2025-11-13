--// Safe Orbit Controller v4 //--
-- Compact UI, adjustable settings, all previous features

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

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

local tracked = {}
local lastScan = 0
local spinMultiplier = 1

-- RESPWAN FIX
player.CharacterAdded:Connect(function(c)
    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
end)

-- FUNCTION: Attach / Orbit Parts (unchanged)
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

-- ORBIT COMPUTATION
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
-- COMPACT GUI
----------------------------------------------
local pg = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui", pg)
gui.ResetOnSpawn = false
gui.Name = "OrbitCompact"

local toggle = Instance.new("TextButton", gui)
toggle.Size = UDim2.new(0,120,0,35)
toggle.Position = UDim2.new(0,10,0,10)
toggle.Text = "Orbit Menu"
toggle.TextScaled = true
toggle.BackgroundColor3 = Color3.fromRGB(50,50,50)
toggle.TextColor3 = Color3.new(1,1,1)

local frame = Instance.new("ScrollingFrame", gui)
frame.Size = UDim2.new(0,220,0,300)
frame.Position = UDim2.new(0,10,0,50)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.Visible = false
frame.CanvasSize = UDim2.new(0,0,0,600)
frame.ScrollBarThickness = 6

toggle.MouseButton1Click:Connect(function()
    frame.Visible = not frame.Visible
end)

-- BUTTON + SLIDER CREATOR
local function createButton(text,posY,callback)
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1,-20,0,30)
    btn.Position = UDim2.new(0,10,0,posY)
    btn.Text = text
    btn.TextScaled = true
    btn.BackgroundColor3 = Color3.fromRGB(100,100,100)
    btn.MouseButton1Click:Connect(callback)
end

local function createSlider(text,posY,min,max,settingKey)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1,-20,0,20)
    label.Position = UDim2.new(0,10,0,posY)
    label.Text = text.." : "..SETTINGS[settingKey]
    label.TextScaled = true
    label.BackgroundTransparency = 1
    local slider = Instance.new("TextBox", frame)
    slider.Size = UDim2.new(1,-20,0,25)
    slider.Position = UDim2.new(0,10,0,posY+20)
    slider.Text = tostring(SETTINGS[settingKey])
    slider.BackgroundColor3 = Color3.fromRGB(80,80,80)
    slider.TextScaled = true
    slider.FocusLost:Connect(function()
        local val = tonumber(slider.Text)
        if val then
            SETTINGS[settingKey] = math.clamp(val,min,max)
            label.Text = text.." : "..SETTINGS[settingKey]
        end
    end)
end

-- CREATE ALL BUTTONS / SLIDERS
local y = 10
createButton("Launch Out",y,function()
    for part in pairs(tracked) do
        part.Velocity = (part.Position - hrp.Position).Unit * 200
    end
end) y=y+50
createButton("Pull In",y,function()
    for _, data in pairs(tracked) do
        data.target.CFrame = hrp.CFrame * CFrame.new(0,2,0)
    end
end) y=y+50
createButton("Spin Up",y,function() spinMultiplier = spinMultiplier+0.5 end) y=y+50
createButton("Explode",y,function()
    for part in pairs(tracked) do
        part.Velocity = Vector3.new(math.random(-200,200),math.random(50,200),math.random(-200,200))
    end
end) y=y+50
createButton("Shield Mode",y,function() SETTINGS.ORBIT_RADIUS=15 SETTINGS.ORBIT_MODE="Sphere" end) y=y+50
createButton("Orbit Enemy",y,function()
    for _,p in pairs(Players:GetPlayers()) do
        if p~=player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            SETTINGS.ENEMY_TARGET=p
            break
        end
    end
end) y=y+50
createButton("Blackhole",y,function() SETTINGS.ORBIT_MODE="Blackhole" end) y=y+50
createButton("Save Preset",y,function()
    writefile("OrbitPreset.json",HttpService:JSONEncode(SETTINGS))
end) y=y+50
createButton("Load Preset",y,function()
    if isfile("OrbitPreset.json") then
        SETTINGS=HttpService:JSONDecode(readfile("OrbitPreset.json"))
    end
end) y=y+50

-- Sliders for orbit radius/speed/max parts
createSlider("Orbit Radius",y,1,100,"ORBIT_RADIUS") y=y+50
createSlider("Orbit Speed",y,0,10,"ORBIT_SPEED") y=y+50
createSlider("Max Parts",y,1,200,"MAX_PARTS") y=y+50
