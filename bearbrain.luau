--[[
made by: 𝕝𝕦𝕟𝕒𝕣𝕓𝕣𝕖𝕓𝕖𝕒𝕦𝕥𝕪 aka 𝕖𝕝_𝕧𝕚𝕣𝕖𝕩𝕦𝕤!!

standalone BEAR skin brain.

handles:
- Bear-only detection
- universal fallback
- idle/walk frames
- walk animation speed
- normal/ping-pong cycles
- frame jiggle
- billboard settings
- cleanup
- respawn reapply
- theme sound
]]

--// services //--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local Player = Players.LocalPlayer

--// state //--

local CurrentGui
local CurrentSound
local CurrentCharacter

local Connections = {}
local Destroyed = false

--// helpers //--

local function disconnectAll()
    for _, connection in ipairs(Connections) do
        if connection then
            connection:Disconnect()
        end
    end

    table.clear(Connections)
end

local function hasBearTeam()
    local team = Teams:FindFirstChild("Bear")

    return team and team:IsA("Team")
end

local function isBear()
    if not hasBearTeam() then
        return true
    end

    if Player.Team and Player.Team.Name == "Bear" then
        return true
    end

    local role = Player:FindFirstChild("Role")

    if role and role:IsA("StringValue") and role.Value == "Bear" then
        return true
    end

    local playerTeam = Player:FindFirstChild("Team")

    if playerTeam and playerTeam:IsA("StringValue") and playerTeam.Value == "Bear" then
        return true
    end

    local leaderstats = Player:FindFirstChild("leaderstats")

    if leaderstats then
        local leaderRole = leaderstats:FindFirstChild("Role")

        if leaderRole
            and leaderRole:IsA("StringValue")
            and leaderRole.Value == "Bear"
        then
            return true
        end
    end

    local character = Player.Character

    if character then
        local characterRole = character:FindFirstChild("Role")

        if characterRole
            and characterRole:IsA("StringValue")
            and characterRole.Value == "Bear"
        then
            return true
        end
    end

    return false
end

local function validImageId(id)
    if type(id) ~= "string" then
        return nil
    end

    if id == "" then
        return nil
    end

    if not string.find(id, "rbxassetid://", 1, true) then
        return "rbxassetid://" .. id
    end

    return id
end

local function destroyGui()
    if CurrentGui then
        CurrentGui:Destroy()
        CurrentGui = nil
    end
end

local function destroySound()
    if CurrentSound then
        CurrentSound:Destroy()
        CurrentSound = nil
    end
end

local function cleanupOtherGuis(hrp, head, current)
    if hrp then
        for _, child in ipairs(hrp:GetChildren()) do
            if child:IsA("BillboardGui") and child ~= current then
                child:Destroy()
            end
        end
    end

    if head then
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("BillboardGui") and child ~= current then
                child:Destroy()
            end
        end
    end
end

--// frames //--

local function createFrame(gui, name, image, config)
    local frame = Instance.new("ImageLabel")

    frame.Name = name
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Position = UDim2.new(0, 0, 0, 0)
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Image = validImageId(image) or ""
    frame.ImageColor3 = config.BillboardColorTint or Color3.new(1, 1, 1)
    frame.ImageTransparency = config.ImageTransparency or 0
    frame.Visible = false
    frame.Parent = gui

    return frame
end

local function setFrameVisible(frames, index)
    for i, frame in ipairs(frames) do
        frame.Visible = i == index
    end
end

--// sound //--

local function createThemeSound(hrp, config)
    if not config.ThemeSound then
        return
    end

    if config.ThemeSound.Enabled ~= true then
        return
    end

    local soundId = config.ThemeSound.SoundId

    if type(soundId) ~= "string" or soundId == "" then
        return
    end

    local sound = Instance.new("Sound")

    sound.Name = (config.SkinName or "Skin") .. "_Theme"
    sound.SoundId = validImageId(soundId)
    sound.Volume = config.ThemeSound.Volume or 1
    sound.PlaybackSpeed = config.ThemeSound.PlaybackSpeed or 1
    sound.Looped = config.ThemeSound.Looped ~= false
    sound.RollOffMode = Enum.RollOffMode.Inverse
    sound.Parent = hrp

    CurrentSound = sound

    sound:Play()
end

--// apply //--

local function applySkin(config, character)
    if Destroyed then
        return
    end

    if config.BearOnly == true and not isBear() then
        destroyGui()
        destroySound()
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")

    if not humanoid or not hrp or not head then
        return
    end

    destroyGui()
    destroySound()

    local oldHrpGui = hrp:FindFirstChild("BillboardGui")

    if oldHrpGui then
        oldHrpGui:Destroy()
    end

    local oldHeadGui = head:FindFirstChild("BillboardGui")

    if oldHeadGui then
        oldHeadGui:Destroy()
    end

    local gui = Instance.new("BillboardGui")

    gui.Name = config.SkinName or "CustomSkin"
    gui.Adornee = hrp
    gui.Size = UDim2.new(
        config.SizeX or 3.2,
        0,
        config.SizeY or 7,
        0
    )

    gui.StudsOffset = config.StudsOffset
        or Vector3.new(0, 0.25, 0)

    gui.AlwaysOnTop = config.AlwaysOnTop == true
    gui.LightInfluence = 0
    gui.ResetOnSpawn = false
    gui.Parent = hrp

    CurrentGui = gui
    CurrentCharacter = character

    local idleFrames = {}
    local walkFrames = {}

    --// idle //--

    if type(config.IdleFrames) == "table" then
        for i, image in ipairs(config.IdleFrames) do
            local frame = createFrame(
                gui,
                "Idle" .. i,
                image,
                config
            )

            table.insert(idleFrames, frame)
        end
    end

    --// walk //--

    if type(config.WalkFrames) == "table" then
        for i, image in ipairs(config.WalkFrames) do
            local frame = createFrame(
                gui,
                "Walk" .. i,
                image,
                config
            )

            table.insert(walkFrames, frame)
        end
    end

    if #idleFrames == 0 and #walkFrames == 0 then
        return
    end

    if #idleFrames > 0 then
        setFrameVisible(idleFrames, 1)
    end

    --// sound //--

    createThemeSound(hrp, config)

    --// animation //--

    local walkTime = 0
    local walkFrame = 1
    local walkDirection = 1
    local wasMoving = false

    local jiggleTime = 0

    local defaultFrameSpeed = 1 / 8

    local function getFrameSpeed()
        if type(config.WalkFrameSwitchSpeed) == "number"
            and config.WalkFrameSwitchSpeed > 0
        then
            return config.WalkFrameSwitchSpeed
        end

        return defaultFrameSpeed
    end

    local function resetWalk()
        walkTime = 0
        walkFrame = 1
        walkDirection = 1
        wasMoving = false

        if #walkFrames > 0 then
            setFrameVisible(walkFrames, 1)
        end
    end

    local animationConnection

    animationConnection = RunService.Heartbeat:Connect(function(dt)
        if Destroyed then
            return
        end

        if not character.Parent
            or not humanoid.Parent
            or not hrp.Parent
        then
            if animationConnection then
                animationConnection:Disconnect()
            end

            return
        end

        if config.BearOnly == true and not isBear() then
            destroyGui()
            destroySound()

            if animationConnection then
                animationConnection:Disconnect()
            end

            return
        end

        local moving = humanoid.MoveDirection.Magnitude > 0

        --// idle //--

        if not moving then
            if wasMoving then
                resetWalk()
            end

            for _, frame in ipairs(idleFrames) do
                frame.Visible = false
            end

            for _, frame in ipairs(walkFrames) do
                frame.Visible = false
            end

            if #idleFrames > 0 then
                idleFrames[1].Visible = true
            elseif #walkFrames > 0 then
                walkFrames[1].Visible = true
            end

            wasMoving = false

            return
        end

        --// walk //--

        if not wasMoving then
            walkTime = 0
            walkFrame = 1
            walkDirection = 1
            wasMoving = true

            if #walkFrames > 0 then
                setFrameVisible(walkFrames, 1)
            end
        end

        for _, frame in ipairs(idleFrames) do
            frame.Visible = false
        end

        if #walkFrames > 0 then
            walkTime += dt

            local frameSpeed = getFrameSpeed()

            if walkTime >= frameSpeed then
                walkTime -= frameSpeed

                if #walkFrames > 1 then
                    if config.WalkFrameCycle == true then
                        walkFrame += walkDirection

                        if walkFrame >= #walkFrames then
                            walkFrame = #walkFrames
                            walkDirection = -1
                        elseif walkFrame <= 1 then
                            walkFrame = 1
                            walkDirection = 1
                        end
                    else
                        walkFrame += 1

                        if walkFrame > #walkFrames then
                            walkFrame = 1
                        end
                    end
                end

                setFrameVisible(walkFrames, walkFrame)
            end

            --// jiggle //--

            if config.FrameJiggle == true then
                jiggleTime += dt

                local amount = config.FrameJiggleAmount or 0.05

                local x = math.sin(jiggleTime * 20) * amount
                local y = math.cos(jiggleTime * 24) * amount

                for _, frame in ipairs(walkFrames) do
                    frame.Position = UDim2.new(
                        0,
                        x,
                        0,
                        y
                    )
                end
            else
                for _, frame in ipairs(walkFrames) do
                    frame.Position = UDim2.new(0, 0, 0, 0)
                end
            end
        end
    end)

    table.insert(Connections, animationConnection)

    --// cleanup //--

    local cleanupConnection

    cleanupConnection = task.spawn(function()
        while not Destroyed
            and character.Parent
            and CurrentGui == gui
        do
            cleanupOtherGuis(
                hrp,
                head,
                gui
            )

            task.wait(config.CleanupInterval or 0.5)
        end
    end)
end

--// start //--

local function start(config)
    if type(config) ~= "table" then
        return
    end

    if Destroyed then
        return
    end

    disconnectAll()

    local function applyCurrent()
        if Destroyed then
            return
        end

        local character = Player.Character

        if not character then
            return
        end

        task.spawn(function()
            local humanoid = character:FindFirstChildOfClass("Humanoid")
                or character:WaitForChild("Humanoid", 10)

            local hrp = character:FindFirstChild("HumanoidRootPart")
                or character:WaitForChild("HumanoidRootPart", 10)

            local head = character:FindFirstChild("Head")
                or character:WaitForChild("Head", 10)

            if humanoid and hrp and head and character.Parent then
                applySkin(config, character)
            end
        end)
    end

    --// initial //--

    if Player.Character then
        applyCurrent()
    end

    --// respawn //--

    if config.ReapplyAfterRespawn ~= false then
        table.insert(
            Connections,
            Player.CharacterAdded:Connect(function()
                task.wait(0.15)
                applyCurrent()
            end)
        )
    end

    --// team changes //--

    table.insert(
        Connections,
        Player:GetPropertyChangedSignal("Team"):Connect(function()
            if config.BearOnly == true then
                applyCurrent()
            end
        end)
    )

    --// role changes //--

    local function watchValue(parent, name)
        local value = parent:FindFirstChild(name)

        if value and value:IsA("StringValue") then
            table.insert(
                Connections,
                value:GetPropertyChangedSignal("Value"):Connect(function()
                    if config.BearOnly == true then
                        applyCurrent()
                    end
                end)
            )
        end
    end

    watchValue(Player, "Role")
    watchValue(Player, "Team")

    local leaderstats = Player:FindFirstChild("leaderstats")

    if leaderstats then
        watchValue(leaderstats, "Role")
    end

    --// bear team changes //--

    table.insert(
        Connections,
        Teams.ChildAdded:Connect(function(child)
            if child.Name == "Bear" and child:IsA("Team") then
                applyCurrent()
            end
        end)
    )

    table.insert(
        Connections,
        Teams.ChildRemoved:Connect(function(child)
            if child.Name == "Bear" then
                applyCurrent()
            end
        end)
    )
end

--// destroy //--

local function destroy()
    if Destroyed then
        return
    end

    Destroyed = true

    disconnectAll()
    destroyGui()
    destroySound()

    CurrentCharacter = nil
end

--// export //--

return {
    Start = start,
    Destroy = destroy,
}