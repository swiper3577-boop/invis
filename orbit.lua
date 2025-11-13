--// Safe Orbit Controller v6 //--
-- Includes: launch, pull, orbit modes, long range pickup, respawn fix, spin-up, explode, shield, enemy orbit, vortex, save/load presets, force sliders, feature toggles

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
    LAUNCH_FORCE = 200,
    PULL_FORCE = 200,
    SHIELD_ENABLED = false,
    BLACKHOLE_ENABLED = false,
    ENEMY_ORBIT_ENABLED = false,
}

-- INTERNALS
local tracked = {}
local lastScan = 0
local spinMultiplier = 1

-- RESPWAN FIX
player.CharacterAdded:Connect(function(c)
    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
end)

----------------------------------------------
-- PART ORBIT SYSTEM
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
-- ORBIT COMPUTATION
----------------------------------------------

local function computeOrbitPosition(i, total)
    local t = tick() * SETTINGS.ORBIT_SPEED * spinMultiplier
    local targetHRP = SETTINGS.ENEMY_ORBIT_ENABLED and SETTINGS.ENEMY_TARGET and SETTINGS.ENEMY_TARGET:FindFirstChild("HumanoidRootPart") or hrp
    if not targetHRP then return Vector3.new() end

    if SETTINGS.ORBIT_MODE == "Ring" then
        local angle = (i / total) * math.pi * 2
        return Vector3.new(
            math.cos(t + angle) * SETTINGS.ORBIT_RADIUS,
            SETTINGS.HEIGHT_OFFSET,
            math.sin(t + angle) * SETTINGS.ORBIT_RADIUS
        )

    elseif SETTINGS.ORBIT_MODE == "Sphere" or SETTINGS.SHIELD_ENABLED then
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

    elseif SETTINGS.ORBIT_MODE == "Blackhole" or SETTINGS.BLACKHOLE_ENABLED then
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
            local targetHRP = SETTINGS.ENEMY_ORBIT_ENABLED and SETTINGS.ENEMY_TARGET and SETTINGS.ENEMY_TARGET:FindFirstChild("HumanoidRootPart") or hrp
            rec.data.target.CFrame = targetHRP.CFrame * CFrame.new(offset)
        end
    end
end)

----------------------------------------------
-- GUI
----------------------------------------------

local pg = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui", pg)
gui.ResetOnSpawn = false
gui.Name = "Orbit6"

local toggle = Instance.new("TextButton", gui)
toggle.Size = UDim2.new(0,150,0,40)
toggle.Position = UDim2.new(0,10,0,10)
toggle.Text = "Open Orbit"
toggle.BackgroundColor3 = Color3.fromRGB(60,60,60)
toggle.TextColor3 = Color3.new(1,1,1)
toggle.TextScaled = true

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0,260,0,500)
frame.Position = UDim2.new(0,50,0,60)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.Visible = false
frame.Draggable = true
frame.Active = true

toggle.MouseButton1Click:Connect(function()
    frame.Visible = not frame.Visible
    toggle.Text = frame.Visible and "Close Orbit" or "Open Orbit"
end)

-- BUTTON CREATOR
local function createButton(text,posY,color,callback)
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1,-20,0,35)
    btn.Position = UDim2.new(0,10,0,posY)
    btn.Text = text
    btn.TextScaled = true
    btn.BackgroundColor3 = color
    btn.MouseButton1Click:Connect(callback)
end

-- SLIDER CREATOR
local function createSlider(text,posY,min,max,default,callback)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1,-20,0,25)
    label.Position = UDim2.new(0,10,0,posY)
    label.Text = text..": "..default
    label.TextScaled = true
    label.BackgroundColor3 = Color3.fromRGB(50,50,50)
    
    local slider = Instance.new("TextBox", frame)
    slider.Size = UDim2.new(1,-20,0,25)
    slider.Position = UDim2.new(0,10,0,posY+30)
    slider.Text = tostring(default)
    slider.TextScaled = true
    slider.BackgroundColor3 = Color3.fromRGB(80,80,80)
    slider.ClearTextOnFocus = false
    
    slider.FocusLost:Connect(function()
        local val = tonumber(slider.Text)
        if val then
            callback(val)
            label.Text = text..": "..val
        end
    end)
end

-- LAUNCH OUT
createButton("Launch Out",10,Color3.fromRGB(120,40,40),function()
    for part,data in pairs(tracked) do
        if part and data.alignP then
            data.alignP.Enabled = false
            data.alignO.Enabled = false
            local dir = (part.Position - hrp.Position).Unit
            part.Velocity = dir * SETTINGS.LAUNCH_FORCE + Vector3.new(0,50,0)
            task.delay(1.5,function()
                if data.alignP then data.alignP.Enabled = true end
                if data.alignO then data.alignO.Enabled = true end
            end)
        end
    end
end)

-- PULL IN (fixed: only unanchored parts, excludes players)
createButton("Pull In",60,Color3.fromRGB(40,120,40),function()
    for part,data in pairs(tracked) do
        if part and data.alignP then
            -- Only pull in unanchored parts that are not descendants of any player
            local isPlayerPart = false
            for _, p in pairs(Players:GetPlayers()) do
                if part:IsDescendantOf(p.Character) then
                    isPlayerPart = true
                    break
                end
            end
            if not part.Anchored and not isPlayerPart then
                data.alignP.Enabled = false
                data.alignO.Enabled = false
                local tween = TweenService:Create(part,TweenInfo.new(0.5,Enum.EasingStyle.Quad),{Position = hrp.Position + Vector3.new(0,2,0)})
                tween:Play()
                tween.Completed:Connect(function()
                    if data.alignP then data.alignP.Enabled = true end
                    if data.alignO then data.alignO.Enabled = true end
                end)
            end
        end
    end
end)

-- SPIN UP
createButton("Spin Up",110,Color3.fromRGB(120,120,40),function()
    spinMultiplier = spinMultiplier + 0.5
end)

-- EXPLODE
createButton("Explode",160,Color3.fromRGB(200,80,0),function()
    for part in pairs(tracked) do
        part.Velocity = Vector3.new(
            math.random(-SETTINGS.LAUNCH_FORCE,SETTINGS.LAUNCH_FORCE),
            math.random(50,SETTINGS.LAUNCH_FORCE),
            math.random(-SETTINGS.LAUNCH_FORCE,SETTINGS.LAUNCH_FORCE)
        )
    end
end)

-- SHIELD TOGGLE
createButton("Toggle Shield",210,Color3.fromRGB(40,160,160),function()
    SETTINGS.SHIELD_ENABLED = not SETTINGS.SHIELD_ENABLED
    SETTINGS.ORBIT_MODE = SETTINGS.SHIELD_ENABLED and "Sphere" or "Ring"
end)

-- ENEMY ORBIT TOGGLE
createButton("Orbit Enemy",260,Color3.fromRGB(160,40,160),function()
    SETTINGS.ENEMY_ORBIT_ENABLED = not SETTINGS.ENEMY_ORBIT_ENABLED
    if SETTINGS.ENEMY_ORBIT_ENABLED then
        for _,p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                SETTINGS.ENEMY_TARGET = p
                break
            end
        end
    else
        SETTINGS.ENEMY_TARGET = nil
    end
end)

-- BLACKHOLE TOGGLE
createButton("Blackhole Vortex",310,Color3.fromRGB(0,0,0),function()
    SETTINGS.BLACKHOLE_ENABLED = not SETTINGS.BLACKHOLE_ENABLED
    SETTINGS.ORBIT_MODE = SETTINGS.BLACKHOLE_ENABLED and "Blackhole" or "Ring"
end)

-- ORBIT MODE SELECTOR
local modeBtn = Instance.new("TextButton", frame)
modeBtn.Size = UDim2.new(1,-20,0,35)
modeBtn.Position = UDim2.new(0,10,0,360)
modeBtn.Text = "Mode: Ring"
modeBtn.TextScaled = true
modeBtn.BackgroundColor3 = Color3.fromRGB(40,40,120)

local modes = {"Ring","Sphere","Vertical","Cloud"}
local modeIndex = 1
modeBtn.MouseButton1Click:Connect(function()
    modeIndex = modeIndex % #modes + 1
    SETTINGS.ORBIT_MODE = modes[modeIndex]
    modeBtn.Text = "Mode: "..SETTINGS.ORBIT_MODE
end)

-- FORCE SLIDERS
createSlider("Launch Force",410,50,500,SETTINGS.LAUNCH_FORCE,function(val)
    SETTINGS.LAUNCH_FORCE = val
end)

createSlider("Pull Force",470,50,500,SETTINGS.PULL_FORCE,function(val)
    SETTINGS.PULL_FORCE = val
end)

-- SAVE / LOAD PRESETS
local function savePreset()
    local preset = {}
    for k,v in pairs(SETTINGS) do
        preset[k] = v
    end
    writefile("OrbitPreset.json", game:GetService("HttpService"):JSONEncode(preset))
end

local function loadPreset()
    if not isfile("OrbitPreset.json") then return end
    local json = readfile("OrbitPreset.json")
    local preset = game:GetService("HttpService"):JSONDecode(json)
    for k,v in pairs(preset) do
        SETTINGS[k] = v
    end
end

createButton("Save Preset",530,Color3.fromRGB(80,120,200),savePreset)
createButton("Load Preset",570,Color3.fromRGB(80,200,120),loadPreset)
