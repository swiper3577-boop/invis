--// Safe Orbit Controller V6 Rayfield //--
-- Full client-side FE version

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

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

-- Prevent player collisions with orbiting parts
local function disablePlayerCollision()
    for part,data in pairs(tracked) do
        if part then
            part.CanCollide = false
        end
    end
end

-- RESPWAN FIX
player.CharacterAdded:Connect(function(c)
    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
end)

-- PART ORBIT SYSTEM
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
    if part:IsDescendantOf(char) then return end
    if (part.Position - hrp.Position).Magnitude > SETTINGS.PICKUP_RANGE then return end

    part.Massless = true
    part.CanCollide = false
    part.CanTouch = false

    local target = Instance.new("Part")
    target.Size = Vector3.new(0.2,0.2,0.2)
    target.Transparency = 1
    target.Anchored = true
    target.CanCollide = false
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
        if obj:IsA("BasePart") and not obj.Anchored and not obj:IsDescendantOf(char) then
            attachPart(obj)
            count += 1
            if count >= SETTINGS.MAX_PARTS then break end
        end
    end
end

Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("BasePart") and not obj.Anchored and not obj:IsDescendantOf(char) and SETTINGS.AUTO_ATTACH then
        attachPart(obj)
    end
end)

-- ORBIT COMPUTATION
local function computeOrbitPosition(i,total)
    local t = tick() * SETTINGS.ORBIT_SPEED * spinMultiplier
    local targetHRP = SETTINGS.ENEMY_ORBIT_ENABLED and SETTINGS.ENEMY_TARGET and SETTINGS.ENEMY_TARGET:FindFirstChild("HumanoidRootPart") or hrp
    if not targetHRP then return Vector3.new() end

    if SETTINGS.ORBIT_MODE == "Ring" then
        local angle = (i/total) * math.pi*2
        return Vector3.new(
            math.cos(t+angle)*SETTINGS.ORBIT_RADIUS,
            SETTINGS.HEIGHT_OFFSET,
            math.sin(t+angle)*SETTINGS.ORBIT_RADIUS
        )
    elseif SETTINGS.ORBIT_MODE == "Sphere" or SETTINGS.SHIELD_ENABLED then
        local phi = math.acos(1 - 2*(i/total))
        local theta = math.sqrt(total*math.pi)*phi
        return Vector3.new(
            SETTINGS.ORBIT_RADIUS*math.sin(phi)*math.cos(theta),
            SETTINGS.ORBIT_RADIUS*math.cos(phi),
            SETTINGS.ORBIT_RADIUS*math.sin(phi)*math.sin(theta)
        )
    elseif SETTINGS.ORBIT_MODE == "Vertical" then
        local angle = (i/total) * math.pi*2
        return Vector3.new(
            math.cos(t+angle)*SETTINGS.ORBIT_RADIUS,
            math.sin(t+angle)*SETTINGS.ORBIT_RADIUS,
            0
        )
    elseif SETTINGS.ORBIT_MODE == "Cloud" then
        return Vector3.new(
            math.sin(t+i)*SETTINGS.ORBIT_RADIUS,
            math.cos(t*0.4+i)*SETTINGS.ORBIT_RADIUS*0.5,
            math.cos(t+i*0.3)*SETTINGS.ORBIT_RADIUS
        )
    elseif SETTINGS.ORBIT_MODE == "Blackhole" or SETTINGS.BLACKHOLE_ENABLED then
        local dir = (targetHRP.Position - hrp.Position).Unit
        local dist = (i/total)*SETTINGS.ORBIT_RADIUS
        return dir*-dist + Vector3.new(0,math.sin(t+i)*5,0)
    end
end

RunService.Heartbeat:Connect(function()
    if not hrp or not hrp.Parent then return end

    if tick() - lastScan >= SETTINGS.SCAN_INTERVAL then
        scan()
        lastScan = tick()
    end

    local live = {}
    for part,data in pairs(tracked) do
        if part.Parent and data.target and data.target.Parent then
            table.insert(live,{part=part,data=data})
        else
            cleanupPart(part)
        end
    end

    local total = #live
    if total == 0 then return end

    for i,rec in ipairs(live) do
        local offset = computeOrbitPosition(i,total)
        if rec.data.target then
            local targetHRP = SETTINGS.ENEMY_ORBIT_ENABLED and SETTINGS.ENEMY_TARGET and SETTINGS.ENEMY_TARGET:FindFirstChild("HumanoidRootPart") or hrp
            rec.data.target.CFrame = targetHRP.CFrame * CFrame.new(offset)
        end
    end

    disablePlayerCollision()
end)

-- =========================
-- Rayfield GUI
-- =========================
local Window = Rayfield:CreateWindow({
    Name = "Safe Orbit Controller V6",
    LoadingTitle = "Safe Orbit Controller V6",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "OrbitV6",
        FileName = "Settings"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    }
})

-- Tabs
local MainTab = Window:CreateTab("Main")
local SlidersTab = Window:CreateTab("Sliders")
local ModesTab = Window:CreateTab("Orbit Modes")

-- Buttons
MainTab:CreateButton({Name="Launch Out",Callback=function()
    for part,data in pairs(tracked) do
        if part and data.alignP and not part.Anchored and not part:IsDescendantOf(char) then
            data.alignP.Enabled = false
            data.alignO.Enabled = false
            local dir = (part.Position - hrp.Position).Unit
            part.Velocity = dir*SETTINGS.LAUNCH_FORCE + Vector3.new(0,50,0)
            task.delay(1.5,function()
                if data.alignP then data.alignP.Enabled=true end
                if data.alignO then data.alignO.Enabled=true end
            end)
        end
    end
end})

MainTab:CreateButton({Name="Pull In",Callback=function()
    for part,data in pairs(tracked) do
        if part and data.alignP and not part.Anchored and not part:IsDescendantOf(char) then
            data.alignP.Enabled = false
            data.alignO.Enabled = false
            local tween = TweenService:Create(part,TweenInfo.new(0.5,Enum.EasingStyle.Quad),{Position=hrp.Position+Vector3.new(0,2,0)})
            tween:Play()
            tween.Completed:Connect(function()
                if data.alignP then data.alignP.Enabled=true end
                if data.alignO then data.alignO.Enabled=true end
            end)
        end
    end
end})

MainTab:CreateButton({Name="Spin Up",Callback=function()
    spinMultiplier = spinMultiplier + 0.5
end})

MainTab:CreateButton({Name="Explode",Callback=function()
    for part,data in pairs(tracked) do
        if part and not part:IsDescendantOf(char) then
            part.Velocity = Vector3.new(
                math.random(-SETTINGS.LAUNCH_FORCE,SETTINGS.LAUNCH_FORCE),
                math.random(50,SETTINGS.LAUNCH_FORCE),
                math.random(-SETTINGS.LAUNCH_FORCE,SETTINGS.LAUNCH_FORCE)
            )
        end
    end
end})

MainTab:CreateToggle({Name="Shield Mode",CurrentValue=false,Callback=function(v)
    SETTINGS.SHIELD_ENABLED = v
    SETTINGS.ORBIT_MODE = v and "Sphere" or "Ring"
end})

MainTab:CreateToggle({Name="Orbit Enemy",CurrentValue=false,Callback=function(v)
    SETTINGS.ENEMY_ORBIT_ENABLED = v
    if v then
        for _,p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                SETTINGS.ENEMY_TARGET = p
                break
            end
        end
    else
        SETTINGS.ENEMY_TARGET = nil
    end
end})

MainTab:CreateToggle({Name="Blackhole Vortex",CurrentValue=false,Callback=function(v)
    SETTINGS.BLACKHOLE_ENABLED = v
    SETTINGS.ORBIT_MODE = v and "Blackhole" or "Ring"
end})

-- =========================
-- Sliders Tab
-- =========================
SlidersTab:CreateSlider({
    Name = "Launch Force",
    Range = {50,500},
    Increment = 10,
    Suffix = "",
    CurrentValue = SETTINGS.LAUNCH_FORCE,
    Flag = "LaunchForce",
    Callback = function(val) SETTINGS.LAUNCH_FORCE=val end
})

SlidersTab:CreateSlider({
    Name = "Pull Force",
    Range = {50,500},
    Increment = 10,
    Suffix = "",
    CurrentValue = SETTINGS.PULL_FORCE,
    Flag = "PullForce",
    Callback = function(val) SETTINGS.PULL_FORCE=val end
})

SlidersTab:CreateSlider({
    Name = "Orbit Radius",
    Range = {1,50},
    Increment = 1,
    Suffix = "",
    CurrentValue = SETTINGS.ORBIT_RADIUS,
    Flag = "OrbitRadius",
    Callback = function(val) SETTINGS.ORBIT_RADIUS=val end
})

SlidersTab:CreateSlider({
    Name = "Orbit Speed",
    Range = {0.1,5},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = SETTINGS.ORBIT_SPEED,
    Flag = "OrbitSpeed",
    Callback = function(val) SETTINGS.ORBIT_SPEED=val end
})

SlidersTab:CreateSlider({
    Name = "Height Offset",
    Range = {0,20},
    Increment = 1,
    Suffix = "",
    CurrentValue = SETTINGS.HEIGHT_OFFSET,
    Flag = "HeightOffset",
    Callback = function(val) SETTINGS.HEIGHT_OFFSET=val end
})

SlidersTab:CreateSlider({
    Name = "Max Parts",
    Range = {1,200},
    Increment = 1,
    Suffix = "",
    CurrentValue = SETTINGS.MAX_PARTS,
    Flag = "MaxParts",
    Callback = function(val) SETTINGS.MAX_PARTS=val end
})

-- =========================
-- Orbit Modes Tab
-- =========================
local orbitOptions = {"Ring","Sphere","Vertical","Cloud","Spiral","Wave","Helix","Star","Blackhole"}
ModesTab:CreateDropdown({
    Name = "Orbit Mode",
    Options = orbitOptions,
    CurrentOption = {SETTINGS.ORBIT_MODE},
    MultipleOptions = false,
    Flag = "OrbitModeDropdown",
    Callback = function(option)
        SETTINGS.ORBIT_MODE = option[1]
    end
})
