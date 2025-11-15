--// Multi-Mode FE Playground V1
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- SETTINGS
local SETTINGS = {
    ORBIT_RADIUS = 10,
    ORBIT_SPEED = 1.5,
    HEIGHT_OFFSET = 5,
    MAX_PARTS = 30,
    SCAN_INTERVAL = 2,
    ALIGN_RESPONSIVENESS = 30,
    ALIGN_FORCE = 1e7,
    AUTO_ATTACH = true,
    PICKUP_RANGE = math.huge,
    MODE = "Rain", -- "Rain" or "Puzzle"
    PUZZLE_SHAPE = "Spiral", -- Cube, Pyramid, Spiral, Star
    SPINNING = false,
    LAUNCH_FORCE = 200,
}

-- INTERNALS
local tracked = {}
local lastScan = 0
local spinMultiplier = 1

-- UTILITY FUNCTIONS
local function disableCollision()
    for part,data in pairs(tracked) do
        if part then
            part.CanCollide = false
        end
    end
end

local function cleanupPart(part)
    local info = tracked[part]
    if not info then return end
    if info.target then info.target:Destroy() end
    if info.attachPart then info.attachPart:Destroy() end
    if info.attachTarget then info.attachTarget:Destroy() end
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

-- SCAN WORKSPACE
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

-- ORBIT / PUZZLE COMPUTATION
local function computeOffset(i,total)
    local t = tick() * SETTINGS.ORBIT_SPEED * spinMultiplier

    if SETTINGS.MODE == "Rain" then
        local angle = (i/total) * math.pi*2
        return Vector3.new(
            math.cos(t+angle)*SETTINGS.ORBIT_RADIUS,
            SETTINGS.HEIGHT_OFFSET + math.sin(t+i),
            math.sin(t+angle)*SETTINGS.ORBIT_RADIUS
        )
    elseif SETTINGS.MODE == "Puzzle" then
        if SETTINGS.PUZZLE_SHAPE == "Cube" then
            local side = math.ceil(total^(1/3))
            local x = (i%side)-side/2
            local y = (math.floor(i/side)%side)-side/2
            local z = (math.floor(i/(side*side)))-side/2
            return Vector3.new(x*2, y*2 + SETTINGS.HEIGHT_OFFSET, z*2)
        elseif SETTINGS.PUZZLE_SHAPE == "Spiral" then
            local angle = (i/total)*math.pi*4
            local radius = 1 + i*0.5
            return Vector3.new(math.cos(angle)*radius, i*0.5 + SETTINGS.HEIGHT_OFFSET, math.sin(angle)*radius)
        elseif SETTINGS.PUZZLE_SHAPE == "Pyramid" then
            local layer = math.ceil((i)^0.5)
            local indexInLayer = i - ((layer-1)^2)
            local x = (indexInLayer - layer/2)*2
            local y = layer*1.5
            local z = (indexInLayer - layer/2)*2
            return Vector3.new(x,y,z)
        elseif SETTINGS.PUZZLE_SHAPE == "Star" then
            local angle = (i/total)*math.pi*10
            local radius = SETTINGS.ORBIT_RADIUS
            local y = math.sin(t+i)*3 + SETTINGS.HEIGHT_OFFSET
            return Vector3.new(math.cos(angle)*radius, y, math.sin(angle)*radius)
        end
    end
    return Vector3.new()
end

-- MAIN LOOP
RunService.Heartbeat:Connect(function(dt)
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
        local offset = computeOffset(i,total)
        rec.data.target.CFrame = hrp.CFrame * CFrame.new(offset)
    end

    disableCollision()
end)

-- =========================
-- Rayfield GUI
-- =========================
local Window = Rayfield:CreateWindow({
    Name = "FE Playground Orbit V1",
    LoadingTitle = "FE Playground Orbit V1",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "FEOrbitV1",
        FileName = "Settings"
    },
})

-- Main Tab
local MainTab = Window:CreateTab("Main")
MainTab:CreateToggle({Name="Rain Mode", CurrentValue=true, Callback=function(v)
    SETTINGS.MODE = v and "Rain" or "Puzzle"
end})
MainTab:CreateDropdown({Name="Puzzle Shape", Options={"Cube","Pyramid","Spiral","Star"}, CurrentOption={"Spiral"}, Callback=function(opt)
    SETTINGS.PUZZLE_SHAPE = opt[1]
end})
MainTab:CreateButton({Name="Spin Up", Callback=function() spinMultiplier = spinMultiplier + 0.5 end})
MainTab:CreateButton({Name="Explode", Callback=function()
    for part,data in pairs(tracked) do
        part.Velocity = Vector3.new(
            math.random(-SETTINGS.LAUNCH_FORCE,SETTINGS.LAUNCH_FORCE),
            math.random(50,SETTINGS.LAUNCH_FORCE),
            math.random(-SETTINGS.LAUNCH_FORCE,SETTINGS.LAUNCH_FORCE)
        )
    end
end})

-- Sliders
local SlidersTab = Window:CreateTab("Sliders")
SlidersTab:CreateSlider({Name="Orbit Radius", Range={1,50}, Increment=1, CurrentValue=SETTINGS.ORBIT_RADIUS, Callback=function(v) SETTINGS.ORBIT_RADIUS=v end})
SlidersTab:CreateSlider({Name="Orbit Speed", Range={0.1,5}, Increment=0.1, CurrentValue=SETTINGS.ORBIT_SPEED, Callback=function(v) SETTINGS.ORBIT_SPEED=v end})
SlidersTab:CreateSlider({Name="Height Offset", Range={0,20}, Increment=1, CurrentValue=SETTINGS.HEIGHT_OFFSET, Callback=function(v) SETTINGS.HEIGHT_OFFSET=v end})
SlidersTab:CreateSlider({Name="Max Parts", Range={1,200}, Increment=1, CurrentValue=SETTINGS.MAX_PARTS, Callback=function(v) SETTINGS.MAX_PARTS=v end})
