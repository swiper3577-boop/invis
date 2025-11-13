local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local realHRP = character:WaitForChild("HumanoidRootPart")

-- State
local isGhost = false
local ghostHRP = nil
local HIDDEN_OFFSET = Vector3.new(0, 1000000, 0)
local GHOST_TRANSPARENCY = 0.5  -- translucent

-- Function to activate ghost
local function activateGhost()
    if isGhost then return end
    isGhost = true

    local originalPos = realHRP.Position

    -- Move real HRP far away
    player.Character:MoveTo(originalPos + HIDDEN_OFFSET)
    wait(0.1)

    -- Clone HRP for ghost
    ghostHRP = realHRP:Clone()
    wait(0.1)

    -- Destroy original HRP (local ghost replaces it)
    realHRP:Destroy()
    ghostHRP.Parent = character
    ghostHRP.Name = "GhostHRP"

    -- Make ghost translucent
    ghostHRP.Transparency = GHOST_TRANSPARENCY

    -- Move ghost to original position
    player.Character:MoveTo(originalPos)
end

-- Function to deactivate ghost
local function deactivateGhost()
    if not isGhost or not ghostHRP then return end

    -- Create a new real HRP
    local newHRP = Instance.new("Part")
    newHRP.Size = Vector3.new(2,2,1)
    newHRP.Name = "HumanoidRootPart"
    newHRP.Anchored = false
    newHRP.CanCollide = true
    newHRP.CFrame = ghostHRP.CFrame
    newHRP.Parent = character

    -- Reconnect Humanoid
    local newHumanoid = humanoid
    newHumanoid.Parent = character

    -- Remove ghost HRP
    ghostHRP:Destroy()
    ghostHRP = nil

    isGhost = false
end

-- Example toggle with a key (G)
game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.G then
        if isGhost then
            deactivateGhost()
        else
            activateGhost()
        end
    end
end)
