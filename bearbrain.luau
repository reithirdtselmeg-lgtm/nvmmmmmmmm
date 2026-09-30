--[[
made by: 𝕝𝕦𝕟𝕒𝕣𝕓𝕣𝕖𝕒𝕦𝕥𝕪 aka 𝕖𝕝_𝕧𝕚𝕣𝕖𝕩𝕦𝕤!!

standalone BEAR skin brain.

handles:
- Bear-only detection
- universal fallback
- idle/walk frames
- walk animation speed
- normal/ping-pong cycles
- frame-change squash jiggle
- billboard settings
- cleanup
- respawn reapply
- looping theme sound
]]

--// services //--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local Player = Players.LocalPlayer

--// state //--

local CurrentGui
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

    local teamValue = Player:FindFirstChild("Team")

    if teamValue
        and teamValue:IsA("StringValue")
        and teamValue.Value == "Bear"
    then
        return true
    end

    local leaderstats = Player:FindFirstChild("leaderstats")

    if leaderstats then
        local roleValue = leaderstats:FindFirstChild("Role")

        if roleValue
            and roleValue:IsA("StringValue")
            and roleValue.Value == "Bear"
        then
            return true
        end
    end

    local character = Player.Character

    if character then
        local roleValue = character:FindFirstChild("Role")

        if roleValue
            and roleValue:IsA("StringValue")
            and roleValue.Value == "Bear"
        then
            return true
        end
    end

    return false
end

local function assetId(id)
    if type(id) ~= "string" or id == "" then
        return ""
    end

    if string.find(id, "rbxassetid://", 1, true) then
        return id
    end

    return "rbxassetid://" .. id
end

local function destroyCurrent()
    if CurrentGui then
        CurrentGui:Destroy()
        CurrentGui = nil
    end

    CurrentCharacter = nil
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
            if child:IsA("BillboardGui") then
                child:Destroy()
            end
        end
    end
end

--// frame //-- 

local function createFrame(gui, name, image, config)
    local frame = Instance.new("ImageLabel")

    frame.Name = name
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Position = UDim2.new(0, 0, 0, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Image = assetId(image)
    frame.ImageColor3 =
        config.BillboardColorTint or Color3.new(1, 1, 1)
    frame.ImageTransparency = config.ImageTransparency or 0
    frame.Visible = false
    frame.Parent = gui

    return frame
end

local function showFrame(frames, index)
    for i, frame in ipairs(frames) do
        frame.Visible = i == index
    end
end

local function resetFrameScale(frames)
    for _, frame in ipairs(frames) do
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.Position = UDim2.new(0, 0, 0, 0)
    end
end

--// sound //--

local function createThemeSound(gui, config)
    local theme = config.ThemeSound

    if not theme or theme.Enabled ~= true then
        return
    end

    if type(theme.SoundId) ~= "string" or theme.SoundId == "" then
        return
    end

    local sound = Instance.new("Sound")

    sound.Name = "ThemeSound"
    sound.SoundId = assetId(theme.SoundId)
    sound.Volume = theme.Volume or 1
    sound.PlaybackSpeed = theme.PlaybackSpeed or 1
    sound.Looped = true
    sound.Parent = gui

    sound:Play()
end

--// jiggle //--

local function applyJiggle(frames, amount, progress)
    amount = amount or 0.3

    local squash = 1 - (amount * progress)
    local stretch = 1 + (amount * progress)

    for _, frame in ipairs(frames) do
        frame.Size = UDim2.new(
            stretch,
            0,
            squash,
            0
        )

        frame.Position = UDim2.new(
            (1 - stretch) / 2,
            0,
            1 - squash,
            0
        )
    end
end

--// apply //--

local function applySkin(config, character)
    if Destroyed then
        return
    end

    if config.BearOnly == true and not isBear() then
        destroyCurrent()
        return
    end

    local humanoid =
        character:FindFirstChildOfClass("Humanoid")

    local hrp =
        character:FindFirstChild("HumanoidRootPart")

    local head =
        character:FindFirstChild("Head")

    if not humanoid or not hrp or not head then
        return
    end

    destroyCurrent()

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

    gui.StudsOffset =
        config.StudsOffset or Vector3.new(0, 0.25, 0)

    gui.AlwaysOnTop =
        config.AlwaysOnTop == true

    gui.LightInfluence = 0
    gui.ResetOnSpawn = false
    gui.Parent = hrp

    CurrentGui = gui
    CurrentCharacter = character

    --// frames //--

    local idleFrames = {}
    local walkFrames = {}

    if type(config.IdleFrames) == "table" then
        for i, image in ipairs(config.IdleFrames) do
            table.insert(
                idleFrames,
                createFrame(
                    gui,
                    "Idle" .. i,
                    image,
                    config
                )
            )
        end
    end

    if type(config.WalkFrames) == "table" then
        for i, image in ipairs(config.WalkFrames) do
            table.insert(
                walkFrames,
                createFrame(
                    gui,
                    "Walk" .. i,
                    image,
                    config
                )
            )
        end
    end

    if #idleFrames == 0 and #walkFrames == 0 then
        return
    end

    --// sound //--

    createThemeSound(gui, config)

    --// animation //--

    local walkTime = 0
    local walkFrame = 1
    local walkDirection = 1
    local wasMoving = false

    local jiggleTime = 0
    local jiggleActive = false

    local frameSpeed =
        type(config.WalkFrameSwitchSpeed) == "number"
        and config.WalkFrameSwitchSpeed > 0
        and config.WalkFrameSwitchSpeed
        or (1 / 8)

    local animationConnection

    animationConnection =
        RunService.Heartbeat:Connect(function(dt)

            if Destroyed then
                return
            end

            if not character.Parent
                or not humanoid.Parent
                or not hrp.Parent
                or CurrentGui ~= gui
            then
                if animationConnection then
                    animationConnection:Disconnect()
                end

                return
            end

            if config.BearOnly == true
                and not isBear()
            then
                destroyCurrent()

                if animationConnection then
                    animationConnection:Disconnect()
                end

                return
            end

            local moving =
                humanoid.MoveDirection.Magnitude > 0

            --// idle //--

            if not moving then
                if wasMoving then
                    walkTime = 0
                    walkFrame = 1
                    walkDirection = 1
                end

                wasMoving = false
                jiggleActive = false
                jiggleTime = 0

                resetFrameScale(idleFrames)
                resetFrameScale(walkFrames)

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

                return
            end

            --// walk //--

            if not wasMoving then
                wasMoving = true
                walkTime = 0
                walkFrame = 1
                walkDirection = 1
                jiggleActive = false
                jiggleTime = 0

                if #walkFrames > 0 then
                    showFrame(walkFrames, 1)
                end
            end

            for _, frame in ipairs(idleFrames) do
                frame.Visible = false
            end

            if #walkFrames == 0 then
                return
            end

            walkTime += dt

            --// squash //--

            if config.FrameJiggle == true then
                if not jiggleActive
                    and walkTime >= frameSpeed * 0.65
                then
                    jiggleActive = true
                    jiggleTime = 0
                end

                if jiggleActive then
                    jiggleTime += dt

                    local jiggleDuration =
                        frameSpeed * 0.35

                    local progress =
                        math.clamp(
                            jiggleTime / jiggleDuration,
                            0,
                            1
                        )

                    applyJiggle(
                        walkFrames,
                        config.FrameJiggleAmount,
                        progress
                    )
                end
            end

            --// frame change //--

            if walkTime >= frameSpeed then
                walkTime -= frameSpeed

                jiggleActive = false
                jiggleTime = 0

                resetFrameScale(walkFrames)

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

                showFrame(
                    walkFrames,
                    walkFrame
                )
            end
        end)

    table.insert(
        Connections,
        animationConnection
    )

    --// cleanup //--

    task.spawn(function()
        while not Destroyed
            and character.Parent
            and CurrentGui == gui
        do
            cleanupOtherGuis(
                hrp,
                head,
                gui
            )

            task.wait(
                config.CleanupInterval or 0.5
            )
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
            local humanoid =
                character:FindFirstChildOfClass("Humanoid")
                or character:WaitForChild("Humanoid", 10)

            local hrp =
                character:FindFirstChild("HumanoidRootPart")
                or character:WaitForChild(
                    "HumanoidRootPart",
                    10
                )

            local head =
                character:FindFirstChild("Head")
                or character:WaitForChild(
                    "Head",
                    10
                )

            if humanoid
                and hrp
                and head
                and character.Parent
            then
                applySkin(
                    config,
                    character
                )
            end
        end)
    end

    --// initial //--

    applyCurrent()

    --// respawn //--

    if config.ReapplyAfterRespawn ~= false then
        table.insert(
            Connections,
            Player.CharacterAdded:Connect(function()
                destroyCurrent()
                task.wait(0.15)
                applyCurrent()
            end)
        )
    end

    --// team //--

    table.insert(
        Connections,
        Player:GetPropertyChangedSignal("Team"):Connect(function()
            if config.BearOnly == true then
                applyCurrent()
            end
        end)
    )

    --// role //--

    local function watchValue(parent, name)
        local value = parent:FindFirstChild(name)

        if value and value:IsA("StringValue") then
            table.insert(
                Connections,
                value:GetPropertyChangedSignal("Value"):Connect(
                    function()
                        if config.BearOnly == true then
                            applyCurrent()
                        end
                    end
                )
            )
        end
    end

    watchValue(Player, "Role")
    watchValue(Player, "Team")

    local leaderstats =
        Player:FindFirstChild("leaderstats")

    if leaderstats then
        watchValue(
            leaderstats,
            "Role"
        )
    end

    --// bear team //--

    table.insert(
        Connections,
        Teams.ChildAdded:Connect(function(child)
            if child.Name == "Bear"
                and child:IsA("Team")
            then
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
    destroyCurrent()
end

--// export //--

return {
    Start = start,
    Destroy = destroy,
}