--// Safe Orbit Controller v7 (Rayfield GUI) //-- 
-- Full upgrade of v6 into Rayfield with all features, sliders, dropdowns, and tabs --

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

    -- Ensure player collision is disabled
    if char and char:FindFirstChildWhichIsA("Humanoid") then
        part.CanCollide = false
    end

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
    local targetHRP = (SETTINGS.ENEMY_ORBIT_ENABLED and SETTINGS.ENEMY_TARGET and SETTINGS.ENEMY_TARGET:FindFirstChild("HumanoidRootPart")) or hrp
    if not targetHRP then return Vector3.new() end

    if SETTINGS.ORBIT_MODE == "Ring" then
        local angle = (i / total) * math.pi * 2
        return Vector3.new(math.cos(t+angle)*SETTINGS.ORBIT_RADIUS, SETTINGS.HEIGHT_OFFSET, math.sin(t+angle)*SETTINGS.ORBIT_RADIUS)
    elseif SETTINGS.ORBIT_MODE == "Sphere" or SETTINGS.SHIELD_ENABLED then
        local phi = math.acos(1 - 2*(i/total))
        local theta = math.sqrt(total*math.pi)*phi
        return Vector3.new(
            SETTINGS.ORBIT_RADIUS*math.sin(phi)*math.cos(theta),
            SETTINGS.ORBIT_RADIUS*math.cos(phi),
            SETTINGS.ORBIT_RADIUS*math.sin(phi)*math.sin(theta)
        )
    elseif SETTINGS.ORBIT_MODE == "Vertical" then
        local angle = (i/total)*math.pi*2
        return Vector3.new(math.cos(t+angle)*SETTINGS.ORBIT_RADIUS, math.sin(t+angle)*SETTINGS.ORBIT_RADIUS, 0)
    elseif SETTINGS.ORBIT_MODE == "Cloud" then
        return Vector3.new(math.sin(t+i)*SETTINGS.ORBIT_RADIUS, math.cos(t*0.4+i)*SETTINGS.ORBIT_RADIUS*0.5, math.cos(t+i*0.3)*SETTINGS.ORBIT_RADIUS)
    elseif SETTINGS.ORBIT_MODE == "Blackhole" or SETTINGS.BLACKHOLE_ENABLED then
        local dir = (targetHRP.Position - hrp.Position).Unit
        local dist = (i/total)*SETTINGS.ORBIT_RADIUS
        return dir*-dist + Vector3.new(0, math.sin(t+i)*5,0)
    elseif SETTINGS.ORBIT_MODE == "Spiral" then
        local angle = (i/total)*math.pi*4
        return Vector3.new(math.cos(t+angle)*SETTINGS.ORBIT_RADIUS, i*0.5, math.sin(t+angle)*SETTINGS.ORBIT_RADIUS)
    elseif SETTINGS.ORBIT_MODE == "Wave" then
        return Vector3.new(math.sin(t+i)*SETTINGS.ORBIT_RADIUS, math.cos(t+i)*SETTINGS.ORBIT_RADIUS, math.sin(t*0.5+i*0.5)*SETTINGS.ORBIT_RADIUS)
    elseif SETTINGS.ORBIT_MODE == "Helix" then
        local angle = (i/total)*math.pi*4
        return Vector3.new(math.cos(t+angle)*SETTINGS.ORBIT_RADIUS, i*0.5, math.sin(t+angle)*SETTINGS.ORBIT_RADIUS)
    elseif SETTINGS.ORBIT_MODE == "Star" then
        local angle = (i/total)*math.pi*2
        return Vector3.new(math.cos(t*2+angle)*SETTINGS.ORBIT_RADIUS, math.sin(t*3+angle)*SETTINGS.ORBIT_RADIUS, math.sin(t+angle)*SETTINGS.ORBIT_RADIUS)
    end
end

RunService.Heartbeat:Connect(function()
    if not hrp or not hrp.Parent then return end
    if tick()-lastScan >= SETTINGS.SCAN_INTERVAL then
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
            local targetHRP = (SETTINGS.ENEMY_ORBIT_ENABLED and SETTINGS.ENEMY_TARGET and SETTINGS.ENEMY_TARGET:FindFirstChild("HumanoidRootPart")) or hrp
            rec.data.target.CFrame = targetHRP.CFrame * CFrame.new(offset)
        end
    end
end)

----------------------------------------------
-- RAYFIELD GUI
----------------------------------------------

local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then
    warn("Failed to load Rayfield GUI. Make sure HTTP requests are enabled.")
    return
    
end
   local Window = Rayfield:CreateWindow({
   Name = "Safe Orbit Controller v7",
   LoadingTitle = "Safe Orbit Controller",
   LoadingSubtitle = "v7 - Rayfield GUI",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "SafeOrbitV7",
      FileName = "OrbitConfig"
   },
   Discord = {
      Enabled = false,
   },
   KeySystem = false
})

-- Tabs
local MainTab = Window:CreateTab("Main")
local SlidersTab = Window:CreateTab("Sliders")
local OrbitTab = Window:CreateTab("Orbit Modes")

-- MAIN BUTTONS
MainTab:CreateButton({Name="Launch Out",Callback=function()
    for part,data in pairs(tracked) do
        if part and data.alignP then
            data.alignP.Enabled = false
            data.alignO.Enabled = false
            local dir = (part.Position - hrp.Position).Unit
            part.Velocity = dir*SETTINGS.LAUNCH_FORCE + Vector3.new(0,50,0)
            task.delay(1.5,function()
                if data.alignP then data.alignP.Enabled = true end
                if data.alignO then data.alignO.Enabled = true end
            end)
        end
    end
end})

MainTab:CreateButton({Name="Pull In",Callback=function()
    for part,data in pairs(tracked) do
        if part and data.alignP and not part.Anchored and not Players:GetPlayerFromCharacter(part.Parent) then
            data.alignP.Enabled = false
            data.alignO.Enabled = false
            local tween = TweenService:Create(part,TweenInfo.new(0.5,Enum.EasingStyle.Quad),{Position=hrp.Position+Vector3.new(0,2,0)})
            tween:Play()
            tween.Completed:Connect(function()
                if data.alignP then data.alignP.Enabled = true end
                if data.alignO then data.alignO.Enabled = true end
            end)
        end
    end
end})

MainTab:CreateButton({Name="Spin Up",Callback=function()
    spinMultiplier = spinMultiplier + 0.5
end})

MainTab:CreateButton({Name="Explode",Callback=function()
    for part in pairs(tracked) do
        part.Velocity = Vector3.new(math.random(-SETTINGS.LAUNCH_FORCE,SETTINGS.LAUNCH_FORCE),
                                    math.random(50,SETTINGS.LAUNCH_FORCE),
                                    math.random(-SETTINGS.LAUNCH_FORCE,SETTINGS.LAUNCH_FORCE))
    end
end})

MainTab:CreateToggle({Name="Shield",CurrentValue=SETTINGS.SHIELD_ENABLED,Callback=function(Value)
    SETTINGS.SHIELD_ENABLED = Value
    SETTINGS.ORBIT_MODE = Value and "Sphere" or "Ring"
end})

MainTab:CreateToggle({Name="Enemy Orbit",CurrentValue=SETTINGS.ENEMY_ORBIT_ENABLED,Callback=function(Value)
    SETTINGS.ENEMY_ORBIT_ENABLED = Value
    if Value then
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

MainTab:CreateToggle({Name="Blackhole Vortex",CurrentValue=SETTINGS.BLACKHOLE_ENABLED,Callback=function(Value)
    SETTINGS.BLACKHOLE_ENABLED = Value
    SETTINGS.ORBIT_MODE = Value and "Blackhole" or "Ring"
end})

MainTab:CreateButton({Name="Save Preset",Callback=function()
    local preset = {}
    for k,v in pairs(SETTINGS) do
        preset[k] = v
    end
    writefile("SafeOrbitPreset.json",HttpService:JSONEncode(preset))
end})

MainTab:CreateButton({Name="Load Preset",Callback=function()
    if isfile("SafeOrbitPreset.json") then
        local preset = HttpService:JSONDecode(readfile("SafeOrbitPreset.json"))
        for k,v in pairs(preset) do
            SETTINGS[k] = v
        end
    end
end})

-- SLIDERS TAB
SlidersTab:CreateSlider({Name="Launch Force",Range={50,500},Increment=10,CurrentValue=SETTINGS.LAUNCH_FORCE,Suffix="",Flag="LaunchForce",Callback=function(Value)
    SETTINGS.LAUNCH_FORCE = Value
end})

SlidersTab:CreateSlider({Name="Pull Force",Range={50,500},Increment=10,CurrentValue=SETTINGS.PULL_FORCE,Suffix="",Flag="PullForce",Callback=function(Value)
    SETTINGS.PULL_FORCE = Value
end})

SlidersTab:CreateSlider({Name="Orbit Radius",Range={1,50},Increment=1,CurrentValue=SETTINGS.ORBIT_RADIUS,Suffix="",Flag="OrbitRadius",Callback=function(Value)
    SETTINGS.ORBIT_RADIUS = Value
end})

SlidersTab:CreateSlider({Name="Orbit Speed",Range={0.1,10},Increment=0.1,CurrentValue=SETTINGS.ORBIT_SPEED,Suffix="",Flag="OrbitSpeed",Callback=function(Value)
    SETTINGS.ORBIT_SPEED = Value
end})

SlidersTab:CreateSlider({Name="Height Offset",Range={0,20},Increment=1,CurrentValue=SETTINGS.HEIGHT_OFFSET,Suffix="",Flag="HeightOffset",Callback=function(Value)
    SETTINGS.HEIGHT_OFFSET = Value
end})

SlidersTab:CreateSlider({Name="Align Force",Range={1e4,1e9},Increment=1e6,CurrentValue=SETTINGS.ALIGN_FORCE,Suffix="",Flag="AlignForce",Callback=function(Value)
    SETTINGS.ALIGN_FORCE = Value
    for _,data in pairs(tracked) do
        if data.alignP then data.alignP.MaxForce = Value end
        if data.alignO then data.alignO.MaxTorque = Value end
    end
end})

SlidersTab:CreateSlider({Name="Align Responsiveness",Range={1,100},Increment=1,CurrentValue=SETTINGS.ALIGN_RESPONSIVENESS,Suffix="",Flag="AlignResp",Callback=function(Value)
    SETTINGS.ALIGN_RESPONSIVENESS = Value
    for _,data in pairs(tracked) do
        if data.alignP then data.alignP.Responsiveness = Value end
        if data.alignO then data.alignO.Responsiveness = Value end
    end
end})

-- ORBIT MODES TAB
local orbitModes = {"Ring","Sphere","Vertical","Cloud","Spiral","Wave","Helix","Star","Blackhole"}
OrbitTab:CreateDropdown({Name="Orbit Mode",Options=orbitModes,CurrentOption={SETTINGS.ORBIT_MODE},MultipleOptions=false,Flag="OrbitModeDropdown",Callback=function(Options)
    SETTINGS.ORBIT_MODE = Options[1]
end})
