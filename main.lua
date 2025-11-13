-- This script creates the GUI and implements the ghost functionality.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

if not Player then return end -- Failsafe if local player is not available

-- Constants
local GHOST_TRANSPARENCY = 0.6 
local GHOST_COLOR = Color3.fromRGB(120, 180, 255) 
local GHOST_MATERIAL = Enum.Material.Neon 
local HIDDEN_CFRAME = CFrame.new(0, -10000, 0) 

-- State Variables
local isGhostActive = false
local ghostClone = nil
local renderSteppedConnection = nil
local realCharacterHRP = nil 
local originalWalkSpeed = 16

-- --- UI CREATION ---
local PlayerGui = Player:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GhostSystemGUI"
ScreenGui.Parent = PlayerGui

local Button = Instance.new("TextButton")
Button.Name = "GhostToggle"
Button.Size = UDim2.new(0, 200, 0, 50)
Button.Position = UDim2.new(0.5, -100, 0.9, -50)
Button.BackgroundColor3 = Color3.fromRGB(0, 102, 204) 
Button.TextColor3 = Color3.fromRGB(255, 255, 255)
Button.Font = Enum.Font.SourceSansBold
Button.TextSize = 22
Button.BorderSizePixel = 0
Button.Text = "Go Ghost Mode (Hide)"
Button.Parent = ScreenGui

-- Use a UICorner object for rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8) 
corner.Parent = Button

-- UI Hover/Click Effects
Button.MouseEnter:Connect(function()
    Button:TweenSize(UDim2.new(0, 210, 0, 55), "Out", "Quad", 0.1, true)
    Button:TweenPosition(UDim2.new(0.5, -105, 0.9, -52), "Out", "Quad", 0.1, true)
end)

Button.MouseLeave:Connect(function()
    Button:TweenSize(UDim2.new(0, 200, 0, 50), "Out", "Quad", 0.1, true)
    Button:TweenPosition(UDim2.new(0.5, -100, 0.9, -50), "Out", "Quad", 0.1, true)
end)

-- --- GHOST LOGIC FUNCTIONS ---

-- Helper function to apply the ghost visuals to a model
local function applyGhostVisuals(model)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = GHOST_TRANSPARENCY
            part.CanCollide = false
            part.Color = GHOST_COLOR
            part.Material = GHOST_MATERIAL
            part.CastShadow = false
        elseif part:IsA("Decal") or part:IsA("Texture") or part:IsA("ShirtGraphic") then
            part:Destroy()
        end
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None 
        humanoid.WalkSpeed = 40 -- Faster movement in ghost mode
    end
end

-- Function to handle character movement synchronization
local function syncClonePosition()
    if realCharacterHRP and ghostClone and ghostClone:FindFirstChild("HumanoidRootPart") then
        local cloneHRP = ghostClone.HumanoidRootPart
        cloneHRP.CFrame = realCharacterHRP.CFrame
    end
end

local function activateGhostMode()
    local character = Player.Character 
    
    -- STEP 0: Wait for character to be fully parented and loaded (aggressive check)
    if not character or not character.Parent then
        -- Wait for a new character if the current one is nil/missing
        character = Player.CharacterAdded:Wait() 
    end
    
    -- Wait until the core components are definitely there
    repeat 
        task.wait() 
        character = Player.Character -- Re-assign in case of quick respawn
    until character and character.Parent and character:FindFirstChild("Humanoid") and character:FindFirstChild("HumanoidRootPart")

    -- Define core components now that we know they exist
    local hrp = character.HumanoidRootPart
    local humanoid = character.Humanoid

    -- Final Check before operations
    if not hrp or not humanoid then 
        warn("Character parts not ready after extensive wait. Aborting ghost mode activation.")
        return 
    end

    -- Store current state
    realCharacterHRP = hrp
    originalWalkSpeed = humanoid.WalkSpeed
    
    -- 1. Create the visual ghost clone using pcall for maximum safety
    local success, clonedModel = pcall(function() return character:Clone() end)
    
    if not success or not clonedModel then
        warn("Failed to clone character model or cloning returned nil. Aborting.")
        return
    end

    ghostClone = clonedModel
    
    -- 2. Name the clone (Safe now)
    ghostClone.Name = Player.Name .. "_GhostClone"
    
    -- 3. Apply ghost visuals
    applyGhostVisuals(ghostClone)
    
    -- 4. Set the clone's starting position and parent it to the workspace
    ghostClone.HumanoidRootPart.CFrame = hrp.CFrame
    ghostClone.Parent = workspace
    
    -- 5. Set the real character's visibility to 1 (invisible locally)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.LocalTransparencyModifier = 1 -- Locally hide the real body
        end
    end
    
    -- 6. TELEPORT THE REAL BODY FAR UNDERGROUND
    hrp.CFrame = HIDDEN_CFRAME 

    -- 7. Start the continuous synchronization loop
    renderSteppedConnection = RunService.Heartbeat:Connect(syncClonePosition)

    -- Update UI and state
    isGhostActive = true
    Button.Text = "Return to Body (Visible)"
end

local function deactivateGhostMode()
    if not ghostClone or not realCharacterHRP then return end

    -- 1. Stop the synchronization loop
    if renderSteppedConnection then
        renderSteppedConnection:Disconnect()
        renderSteppedConnection = nil
    end

    -- 2. Get the final position of the ghost clone
    local finalCFrame = ghostClone.HumanoidRootPart.CFrame
    
    -- 3. TELEPORT THE REAL BODY BACK TO THE GHOST'S POSITION
    realCharacterHRP.CFrame = finalCFrame
    
    -- 4. Restore the real character's visibility (transparency 0)
    local character = Player.Character
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.LocalTransparencyModifier = 0 
            end
        end
        
        -- Reset walkspeed
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = originalWalkSpeed 
        end
    end
    
    -- 5. Destroy the visual ghost clone
    ghostClone:Destroy()
    ghostClone = nil
    realCharacterHRP = nil
    
    -- Update UI and state
    isGhostActive = false
    Button.Text = "Go Ghost Mode (Hide)"
end

-- --- FINAL BINDING ---

-- Button Click Handler
Button.MouseButton1Click:Connect(function()
    if isGhostActive then
        deactivateGhostMode()
    else
        -- Wrap activation in a pcall in case of a fatal error during the process
        local success, err = pcall(activateGhostMode)
        if not success then
            warn("Error during Ghost Mode Activation: " .. tostring(err))
            -- Attempt to clean up if activation failed midway
            if ghostClone then ghostClone:Destroy() end
            isGhostActive = false
            Button.Text = "Go Ghost Mode (Hide)"
        end
    end
end)
