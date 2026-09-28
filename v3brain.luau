--// V3 ENTITY BRAIN //--
--// made by: 𝕝𝕦𝕟𝕒𝕣𝕓𝕣𝕖𝕓𝕖𝕒𝕦𝕥𝕪 aka 𝕖𝕝_𝕧𝕚𝕣𝕖𝕩𝕦𝕤!! //--
--// compact V3 build: V2 foundation + V3 mechanics //--
--[[
NEW CONFIG TYPES

Movement.Type = "NODE"
    Uses the original V2 node/rebound movement.

Movement.Type = "NON-NODE"
    V2 node movement is skipped.
    V3 handles movement independently.
    Movement.FollowPlayer = true or Movement.Target = "PLAYER"
    enables V3 direct player movement; otherwise the entity can remain
    stationary while its V3 damage mechanic operates.

Movement.Type = "CHASER"
    "CHASER" is the PUBLIC / CONFIGURATION name.
    Internally it is a V3-owned, room-aware chase controller
    (see StartChaserMovement).

        entity in a DIFFERENT room than the player
            -> follow RoomEntrance / PathfindNodes / RoomExit
               through every loaded room toward the player's room
        entity in the SAME room as the player
            -> stop following nodes, chase the player directly
        player changes room
            -> the route is rebuilt toward the new room

    Movement.Speed controls BOTH node travel and the direct chase.
    Movement.FollowPlayer / Movement.Target = "PLAYER" identify the player
    as the target, but CHASER itself owns all of the movement logic.

    There is exactly ONE movement authority for CHASER: V3.
    V2's node system is locked out three ways:
        1. BuildV2Config forces FollowPlayer = true for V2 (V2 skips nodes)
        2. the model gets the attribute "V3ChaserMovement" = true
        3. PatchV2Source makes V2 also skip nodes when that attribute is set

    Example:
        Movement = {
            Type = "CHASER",
            Speed = 19,
            Delay = 1,
            Reversed = false,
            FollowPlayer = true,
            Target = "PLAYER",
            FollowPlayerDespawnTime = 150
        }

Damage.Type = "RANGE"
    Uses V2's normal range + line-of-sight damage.

Damage.Type = "LOOK_AND_HURT"
    V3 damages when the player is looking at the entity.
    Damage.Range, Damage.LookCone and Damage.Cooldown are configurable.
    Raycasts block detection through walls/obstacles.

Damage.Type = "LOOK_AND_HURT_OPPOSITE"
    Inverse look condition.
    Uses the same nerfed 8-stud / 55-degree defaults and strict wall protection.
    The entity must be visible and inside range, but outside the look cone.
    Solid raycast obstacles protect the player completely.
    The opposite mechanic cannot damage through walls/obstacles.

BanishmentSound = {
    Id = "139310882854462",
    PlaybackSpeed = 0.8,
    Volume = 1
}
    Plays once when BeingBanished changes to true, alongside V2's
    original crucifix sound.
]]
--// Services //--
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
--// V2 SOURCE //--
local V2_URL =
    "https://raw.githubusercontent.com/reithirdtselmeg-lgtm/nvmmmmmmmm/main/.github/workflows/v2vrainnnn.luau"
--// external asset system //--
local ASSET_FOLDER = "V3Entities"
local ASSET_CLEANUP_DELAY = 20
local ExternalAssetFunctions = {
    HttpGet = type(game.HttpGet) == "function",
    WriteFile = type(writefile) == "function",
    GetCustomAsset = type(getcustomasset) == "function",
    IsFile = type(isfile) == "function",
    DeleteFile = type(delfile) == "function",
    MakeFolder = type(makefolder) == "function"
}
local function IsExternalUrl(value)
    return typeof(value) == "string"
        and (value:match("^https://") or value:match("^http://")) ~= nil
end
local function GetExtension(url, fallback)
    if typeof(url) ~= "string" then
        return fallback
    end
    local cleanUrl =
        url:match("^[^?#]+")
        or url
    local extension =
        cleanUrl:match("%.([%w]+)$")
    if extension and #extension <= 8 then
        return extension:lower()
    end
    return fallback
end
local function SafeIsFile(path)
    if not ExternalAssetFunctions.IsFile then
        return false
    end
    local ok, result = pcall(function()
        return isfile(path)
    end)
    return ok and result == true
end
local function SafeDeleteFile(path)
    if not ExternalAssetFunctions.DeleteFile then
        return
    end
    pcall(function()
        if SafeIsFile(path) then
            delfile(path)
        end
    end)
end
local function EnsureAssetFolder()
    if not ExternalAssetFunctions.MakeFolder then
        return true
    end
    local ok = pcall(function()
        if not isfolder or not isfolder(ASSET_FOLDER) then
            makefolder(ASSET_FOLDER)
        end
    end)
    return ok
end
local function GenerateAssetPath(url, extension)
    local randomPart =
        tostring(math.random(100000, 999999))
        .. "_"
        .. tostring(math.floor(os.clock() * 100000))
    return
        ASSET_FOLDER
        .. "/V3_"
        .. randomPart
        .. "."
        .. extension
end
local function DownloadExternalAsset(url, fallbackExtension)
    if not IsExternalUrl(url) then
        return url, nil
    end
    if not ExternalAssetFunctions.HttpGet
        or not ExternalAssetFunctions.WriteFile
        or not ExternalAssetFunctions.GetCustomAsset
    then
        warn("V3 Brain: external asset requires " .. "HttpGet, writefile, and getcustomasset.")
        return nil, nil
    end
    if not EnsureAssetFolder() then
        warn("V3 Brain: failed to prepare asset folder.")
        return nil, nil
    end
    local ok, data = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok
        or typeof(data) ~= "string"
        or #data == 0
    then
        warn("V3 Brain: failed to download external asset:\n" .. tostring(url))
        return nil, nil
    end
    local extension = GetExtension(url, fallbackExtension)
    local path = GenerateAssetPath(url, extension)
    local writeOk = pcall(function()
        writefile(path, data)
    end)
    if not writeOk then
        warn("V3 Brain: failed to write external asset:\n" .. path)
        return nil, nil
    end
    local customOk, customAsset = pcall(function()
        return getcustomasset(path)
    end)
    if not customOk
        or typeof(customAsset) ~= "string"
        or customAsset == ""
    then
        SafeDeleteFile(path)
        warn("V3 Brain: getcustomasset failed:\n" .. path)
        return nil, nil
    end
    return customAsset, path
end
local function ResolveAsset(value, fallbackExtension, assetList)
    if typeof(value) ~= "string"
        or value == ""
    then
        return value
    end
    if not IsExternalUrl(value) then
        return value
    end
    local resolved, path = DownloadExternalAsset(value, fallbackExtension)
    if path then
        table.insert(assetList, path)
    end
    return resolved
end
local function CleanupAssetFiles(assetList)
    if typeof(assetList) ~= "table" then
        return
    end
    for _, path in ipairs(assetList) do
        if typeof(path) == "string" then
            SafeDeleteFile(path)
        end
    end
    table.clear(assetList)
end
--// resolve all supported config assets //--
local function ResolveConfigAssets(config)
    local assetList = {}
    local function Image(value)
        return ResolveAsset(value, "png", assetList)
    end
    local function Sound(value)
        return ResolveAsset(value, "ogg", assetList)
    end
    config.FaceId = Image(config.FaceId)
    if typeof(config.Auras) == "table" then
        for i, auraData in ipairs(config.Auras) do
            if i > 3 then
                break
            end
            if typeof(auraData) == "table"
                and auraData.Id
            then
                auraData.Id = Image(auraData.Id)
            end
        end
    end
    config.SpawnSound = Sound(config.SpawnSound)
    config.FarRushSound = Sound(config.FarRushSound)
    config.NearRushSound = Sound(config.NearRushSound)
    config.DespawnSound = Sound(config.DespawnSound)
    if config.Jumpscare then
        config.Jumpscare.Image = Image(config.Jumpscare.Image)
        config.Jumpscare.Sound = Sound(config.Jumpscare.Sound)
    end
    return assetList
end
--// V3 MOVEMENT PATCH //--
local function PatchV2Source(source)
    if typeof(source) ~= "string" then
        error("V3 Brain: V2 source is not a string.")
    end
    local patchedSource = source
    --// Callback compatibility //--
    local callbackSource, callbackCount =
        patchedSource:gsub('"OnReachNode"', '"OnReachedNode"')
    patchedSource = callbackSource
    if callbackCount == 0 then
        warn("V3 Brain: " .. "'OnReachNode' -> 'OnReachedNode' " .. "patch matched 0 occurrences.")
    end
    --// Despawn movement speed //--
    local despawnPattern =
        'EntityMoveTo%(model, model:GetPivot%(%) %- Vector3%.new%(0, 300, 0%), config%.Movement%.Speed%)'
    local despawnReplacement =
        'EntityMoveTo(model, model:GetPivot() - Vector3.new(0, 300, 0), 60)'
    local despawnSource, despawnCount =
        patchedSource:gsub(despawnPattern, despawnReplacement)
    patchedSource = despawnSource
    if despawnCount == 0 then
        warn("V3 Brain: V2 despawn movement patch " .. "matched 0 occurrences.")
    end
    --// CHASER lock //--
    -- V2 skips its whole node/pathfinding task when FollowPlayer == true.
    -- CHASER entities already get FollowPlayer = true from BuildV2Config,
    -- but this second lock makes V2 ALSO skip nodes whenever the model
    -- carries the internal V3ChaserMovement attribute. That way V2 can
    -- never independently move a CHASER entity, even if the config
    -- value is ever changed by mistake. Normal NODE entities never carry
    -- the attribute, so their V2 node behavior is untouched.
    local chaserPattern =
        'if config%.Movement%.FollowPlayer == true then'
    local chaserReplacement =
        'if config.Movement.FollowPlayer == true or model:GetAttribute("V3ChaserMovement") == true then'
    local chaserSource, chaserCount =
        patchedSource:gsub(chaserPattern, chaserReplacement)
    patchedSource = chaserSource
    if chaserCount == 0 then
        warn("V3 Brain: V2 CHASER lock patch matched 0 occurrences. "
            .. "CHASER is still protected by FollowPlayer = true.")
    end
    return patchedSource
end
--// Load patched V2 //--
getgenv().VynixuEntitySpawnerV2 = nil
local Original
local function DownloadV2Source()
    local attempts = 3
    local lastError = nil
    for attempt = 1, attempts do
        local cacheBust =
            tostring(os.time())
            .. "_"
            .. tostring(math.floor(os.clock() * 100000))
            .. "_"
            .. tostring(attempt)
        local url =
            V2_URL
            .. "?v="
            .. cacheBust
        local ok, source = pcall(function()
            return game:HttpGet(url)
        end)
        if ok
            and typeof(source) == "string"
            and #source > 10000
        then
            local trimmed = source:gsub("%s+$", "")
            if trimmed:match("return%s+Module%s*$") then
                return source
            end
            lastError =
                "V2 source did not end with "
                .. "'return Module'."
        else
            lastError =
                "V2 HTTP response was invalid "
                .. "or suspiciously short."
        end
        task.wait(0.25)
    end
    error("V3 Brain: failed to download " .. "a complete V2 source.\n" .. tostring(lastError))
end
do
    local source = DownloadV2Source()
    print("V3 Brain: downloaded V2 source:", #source, "characters")
    local patchOk, patchedSource = pcall(function()
        return PatchV2Source(source)
    end)
    if not patchOk then
        error("V3 Brain: failed to patch V2 source:\n" .. tostring(patchedSource))
    end
    print("V3 Brain: patched V2 source:", #patchedSource, "characters")
    local compileOk, V2Function = pcall(function()
        local fn, err = loadstring(patchedSource)
        if not fn then
            error("V3 Brain: patched V2 " .. "COMPILE ERROR:\n" .. tostring(err))
        end
        return fn
    end)
    if not compileOk then
        error(tostring(V2Function))
    end
    local runOk, result = pcall(function()
        return V2Function()
    end)
    if not runOk then
        error("V3 Brain: patched V2 " .. "EXECUTION ERROR:\n" .. tostring(result))
    end
    if typeof(result) ~= "table" then
        error("V3 Brain: patched V2 returned " .. typeof(result) .. " instead of a table.")
    end
    if typeof(result.Create) ~= "function" then
        error("V3 Brain: V2 loaded, " .. "but Create is missing.")
    end
    Original = result
    getgenv().VynixuEntitySpawnerV2 = Original
end
--// colors //--
local AuraColors = {
    Red = Color3.fromRGB(255, 60, 60),
    Orange = Color3.fromRGB(255, 140, 0),
    Yellow = Color3.fromRGB(255, 230, 40),
    YellowGreen = Color3.fromRGB(170, 255, 0),
    Green = Color3.fromRGB(0, 255, 90),
    GreenCyan = Color3.fromRGB(0, 255, 170),
    Cyan = Color3.fromRGB(0, 255, 255),
    Blue = Color3.fromRGB(0, 120, 255),
    StrongBlue = Color3.fromRGB(0, 60, 255),
    StrongBluePurple = Color3.fromRGB(90, 0, 255),
    Purple = Color3.fromRGB(170, 0, 255),
    Pink = Color3.fromRGB(255, 0, 170),
    Magenta = Color3.fromRGB(255, 0, 255),
    MagentaRed = Color3.fromRGB(255, 0, 90),
    White = Color3.fromRGB(255, 255, 255),
    Grey = Color3.fromRGB(128, 128, 128),
    Black = Color3.fromRGB(0, 0, 0)
}
_G.AuraColors = AuraColors
--// color mixer //--
local function MixColors(color1, color2)
    return Color3.new(
        (color1.R + color2.R) / 2,
        (color1.G + color2.G) / 2,
        (color1.B + color2.B) / 2
    )
end
local function GetColor(value)
    if typeof(value) == "Color3" then
        return value
    end
    if typeof(value) ~= "string" then
        return Color3.new(1, 1, 1)
    end
    if AuraColors[value] then
        return AuraColors[value]
    end
    local left, right = value:match("^%s*(.-)%s*%+%s*(.-)%s*$")
    if left and right then
        if string.find(right, "%+") then
            return Color3.new(1, 1, 1)
        end
        local color1 = AuraColors[left]
        local color2 = AuraColors[right]
        if color1 and color2 then
            return MixColors(color1, color2)
        end
    end
    return Color3.new(1, 1, 1)
end
--// state //--
local Brain = {}
local EntityActive = false
local CurrentEntity = nil
local EnvironmentEffect = nil
--// ACTIVE RUSH SOUNDS //--
--//
--// FAR AND NEAR ARE BESTIES.
--// THEY DO NOT CANCEL EACH OTHER.
--//
--// Each one gets ONE instance.
--// FarRush and NearRush can exist
--// simultaneously.
--//
local ActiveSounds = {}
local FarRushSoundInstance = nil
local NearRushSoundInstance = nil
local function SafeDestroy(instance)
    if instance then
        pcall(function()
            instance:Destroy()
        end)
    end
end
local function RegisterSound(sound, soundType)
    if not sound then
        return
    end
    ActiveSounds[sound] = soundType
    if soundType == "FarRush" then
        FarRushSoundInstance = sound
    elseif soundType == "NearRush" then
        NearRushSoundInstance = sound
    end
end
local function UnregisterSound(sound)
    if not sound then
        return
    end
    local soundType = ActiveSounds[sound]
    ActiveSounds[sound] = nil
    if sound == FarRushSoundInstance then
        FarRushSoundInstance = nil
    end
    if sound == NearRushSoundInstance then
        NearRushSoundInstance = nil
    end
    return soundType
end
local function StopSound(sound)
    if not sound then
        return
    end
    pcall(function()
        sound:Stop()
    end)
    UnregisterSound(sound)
    SafeDestroy(sound)
end
local function StopAllActiveSounds()
    local sounds = {}
    for sound in pairs(ActiveSounds) do
        sounds[#sounds + 1] = sound
    end
    for _, sound in ipairs(sounds) do
        StopSound(sound)
    end
    table.clear(ActiveSounds)
    FarRushSoundInstance = nil
    NearRushSoundInstance = nil
end
local function FindFacePart(model)
    if not model then
        return nil
    end
    return model:FindFirstChild("FacePart", true)
        or model:FindFirstChild("Head", true)
        or model.PrimaryPart
end
--// make entity //--
local function PrepareModel(config)
    local model = Instance.new("Model")
    model.Name = config.EntityName or "CustomEntity"
    local root = Instance.new("Part")
    root.Name = "Root"
    root.Size = Vector3.new(2, 2, 2)
    root.Transparency = 1
    root.Anchored = true
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.CastShadow = false
    root.Parent = model
    model.PrimaryPart = root
    local face = Instance.new("Part")
    face.Name = "FacePart"
    face.Size = Vector3.new(4, 4, 0.2)
    face.Transparency = 1
    face.Anchored = false
    face.CanCollide = false
    face.CanTouch = false
    face.CanQuery = false
    face.CastShadow = false
    face.CFrame = root.CFrame * CFrame.new(0, 0, -1.2)
    face.Parent = model
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = face
    weld.Parent = face
    return model
end
--// face //--
local function SetupFace(model, config)
    local facePart = FindFacePart(model)
    if not facePart then
        return
    end
    local faceId = config.FaceId
    if typeof(faceId) ~= "string"
        or faceId == ""
    then
        return
    end
    local attachment = facePart:FindFirstChild("FaceAttachment")
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "FaceAttachment"
        attachment.Parent = facePart
    end
    local emitter = attachment:FindFirstChild("FaceParticle")
    if not emitter then
        emitter = Instance.new("ParticleEmitter")
        emitter.Name = "FaceParticle"
        emitter.Parent = attachment
    end
    emitter.Texture = faceId
    for property, value in pairs(config.FaceParticle or {}) do
        pcall(function()
            emitter[property] = value
        end)
    end
end
--// multi-aura //--
local function SetupAura(model, config)
    local root = model.PrimaryPart
    if not root
        or typeof(config.Auras) ~= "table"
        or #config.Auras == 0
    then
        return
    end
    local firstAura = config.Auras[1]
    if typeof(firstAura) ~= "table"
        or typeof(firstAura.Id) ~= "string"
        or firstAura.Id == ""
    then
        warn("V3 Brain: Aura #1 must " .. "have a valid Id.")
        return
    end
    if firstAura.Color == nil then
        warn("V3 Brain: Aura #1 MUST " .. "define the master Color.")
        return
    end
    local masterColor = GetColor(firstAura.Color)
    local masterColorSequence = ColorSequence.new(masterColor)
    for index = 1, math.min(#config.Auras, 3) do
        local auraData = config.Auras[index]
        if typeof(auraData) == "table"
            and typeof(auraData.Id) == "string"
            and auraData.Id ~= ""
        then
            local attachmentName = "AuraAttachment" .. index
            local particleName = "AuraParticle" .. index
            local attachment = root:FindFirstChild(attachmentName)
            if not attachment then
                attachment = Instance.new("Attachment")
                attachment.Name = attachmentName
                attachment.Parent = root
            end
            local emitter = attachment:FindFirstChild(particleName)
            if not emitter then
                emitter = Instance.new("ParticleEmitter")
                emitter.Name = particleName
                emitter.Parent = attachment
            end
            emitter.Texture = auraData.Id
            emitter.Color = masterColorSequence
            for property, value in pairs(auraData.Settings or {}) do
                pcall(function()
                    emitter[property] = value
                end)
            end
        end
    end
end
--// entity lamp //--
local function SetupLight(model, data, name)
    local root = model.PrimaryPart
    if not root then
        return
    end
    local oldLight = root:FindFirstChild(name)
    if oldLight then
        SafeDestroy(oldLight)
    end
    if not data
        or not data.Enabled
    then
        return
    end
    local light = Instance.new("PointLight")
    light.Name = name
    light.Color = GetColor(data.Color)
    light.Range = data.Range or 30
    light.Brightness = data.Brightness or 2
    light.Enabled = true
    light.Parent = root
    return light
end
--// environment //--
local function SetupEnvironment(config)
    if EnvironmentEffect then
        SafeDestroy(EnvironmentEffect)
        EnvironmentEffect = nil
    end
    local data = config.EnvironmentColor
    if not data
        or not data.Enabled
    then
        return
    end
    local effect = Instance.new("ColorCorrectionEffect")
    effect.Name = "V3EntityEnvironmentColor"
    local targetColor = GetColor(data.Color)
    local strength = math.clamp(tonumber(data.Strength) or 45, 0, 100) / 100
    local targetTint = Color3.new(
        1 + (targetColor.R - 1) * strength,
        1 + (targetColor.G - 1) * strength,
        1 + (targetColor.B - 1) * strength
    )
    effect.TintColor = Color3.new(1, 1, 1)
    effect.Brightness = 0
    effect.Contrast = 0
    effect.Saturation = 0
    effect.Parent = Lighting
    EnvironmentEffect = effect
    local fadeIn = math.max(tonumber(data.FadeIn) or 0.5, 0)
    local tween = TweenService:Create(
        effect,
        TweenInfo.new(fadeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            TintColor = targetTint,
            Brightness = strength * 0.15,
            Contrast = strength * 0.25,
            Saturation = strength * 0.1
        }
    )
    tween:Play()
end
local function RemoveEnvironment(config)
    local effect = EnvironmentEffect
    if not effect then
        return
    end
    EnvironmentEffect = nil
    local data = config.EnvironmentColor or {}
    local fadeOut = math.max(tonumber(data.FadeOut) or 0.5, 0)
    local tween = TweenService:Create(
        effect,
        TweenInfo.new(fadeOut, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            TintColor = Color3.new(1, 1, 1),
            Brightness = 0,
            Contrast = 0,
            Saturation = 0
        }
    )
    tween:Play()
    task.delay(fadeOut, function()
        SafeDestroy(effect)
    end)
end
--// sounds //--
local function CreateSound(parent, soundId, volume, playbackSpeed, name, looped)
    if not parent
        or typeof(soundId) ~= "string"
        or soundId == ""
    then
        return nil
    end
    local sound = Instance.new("Sound")
    sound.Name = name or "V3Sound"
    sound.SoundId = soundId
    sound.Volume = volume ~= nil and volume or 1
    sound.Looped = looped == true
    sound.PlaybackSpeed = playbackSpeed ~= nil and playbackSpeed or 1
    sound.Parent = parent
    return sound
end
--// spawn sound //--
local function PlaySpawnSound(config)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return
    end
    local sound = CreateSound(
        playerGui,
        config.SpawnSound,
        config.SpawnVolume,
        config.SpawnPlaybackSpeed,
        "V3SpawnSound",
        false
    )
    if not sound then
        return
    end
    sound:Play()
    task.delay(config.SpawnSoundTimeout or 5, function()
        SafeDestroy(sound)
    end)
end
--// RUSH SOUNDS //--
--//
--// FarRush + NearRush:
--//
--//     FAR 🤝 NEAR
--//      BESTIES
--//
--// They are completely independent.
--// One NEVER cancels the other.
--//
local function PlayRushSound(model, soundId, volume, playbackSpeed, name, rollOffMaxDistance)
    if not model then
        return nil
    end
    if typeof(soundId) ~= "string"
        or soundId == ""
    then
        return nil
    end
    local facePart = FindFacePart(model)
    if not facePart then
        return nil
    end
    local soundType = name
    if soundType == "FarRush" then
        if FarRushSoundInstance
            and FarRushSoundInstance.Parent
        then
            if not FarRushSoundInstance.IsPlaying then
                FarRushSoundInstance:Play()
            end
            return FarRushSoundInstance
        end
    elseif soundType == "NearRush" then
        if NearRushSoundInstance
            and NearRushSoundInstance.Parent
        then
            if not NearRushSoundInstance.IsPlaying then
                NearRushSoundInstance:Play()
            end
            return NearRushSoundInstance
        end
    end
    local existing = facePart:FindFirstChild(soundType)
    if existing
        and existing:IsA("Sound")
    then
        RegisterSound(existing, soundType)
        if not existing.IsPlaying then
            existing:Play()
        end
        return existing
    end
    local sound = CreateSound(
        facePart,
        soundId,
        volume ~= nil and volume or 1,
        playbackSpeed ~= nil and playbackSpeed or 1,
        soundType,
        true
    )
    if not sound then
        return nil
    end
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = 5
    sound.RollOffMaxDistance = tonumber(rollOffMaxDistance) or 240
    sound.EmitterSize = 5
    RegisterSound(sound, soundType)
    sound:Play()
    return sound
end
--// fade BOTH rush sounds //--
local function FadeOutActiveSounds(duration)
    duration = math.max(tonumber(duration) or 0.9, 0)
    local soundsToFade = {}
    for sound in pairs(ActiveSounds) do
        if sound
            and sound.Parent
        then
            soundsToFade[#soundsToFade + 1] = sound
        else
            UnregisterSound(sound)
        end
    end
    for _, sound in ipairs(soundsToFade) do
        if sound.Parent then
            if duration <= 0 then
                StopSound(sound)
            else
                local tween = TweenService:Create(
                    sound,
                    TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
                    { Volume = 0 }
                )
                tween:Play()
                task.delay(duration, function()
                    if sound and sound.Parent then
                        StopSound(sound)
                    else
                        UnregisterSound(sound)
                    end
                end)
            end
        end
    end
end
--// despawn sound //--
local function PlayDespawnSound(config)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return
    end
    local sound = CreateSound(
        playerGui,
        config.DespawnSound,
        config.DespawnVolume,
        config.DespawnPlaybackSpeed,
        "V3DespawnSound",
        false
    )
    if not sound then
        return
    end
    sound:Play()
    task.delay(config.DespawnSoundTimeout or 5, function()
        SafeDestroy(sound)
    end)
end
--// preload //--
local function Preload(config)
    local assets = {}
    local function AddAsset(id, className)
        if typeof(id) ~= "string"
            or id == ""
        then
            return
        end
        local asset = Instance.new(className)
        asset.Name = "V3Preload"
        if asset:IsA("ImageLabel") then
            asset.Image = id
        elseif asset:IsA("Sound") then
            asset.SoundId = id
        end
        asset.Parent = game:GetService("CoreGui")
        table.insert(assets, asset)
    end
    AddAsset(config.FaceId, "ImageLabel")
    if typeof(config.Auras) == "table" then
        for i, auraData in ipairs(config.Auras) do
            if i > 3 then
                break
            end
            if typeof(auraData) == "table" then
                AddAsset(auraData.Id, "ImageLabel")
            end
        end
    end
    AddAsset(config.SpawnSound, "Sound")
    AddAsset(config.FarRushSound, "Sound")
    AddAsset(config.NearRushSound, "Sound")
    AddAsset(config.DespawnSound, "Sound")
    if config.Jumpscare then
        AddAsset(config.Jumpscare.Image, "ImageLabel")
        AddAsset(config.Jumpscare.Sound, "Sound")
    end
    if #assets > 0 then
        pcall(function()
            ContentProvider:PreloadAsync(assets)
        end)
    end
    for _, asset in ipairs(assets) do
        SafeDestroy(asset)
    end
end
--// jumpscare //--
local function RunJumpscare(config)
    local data = config.Jumpscare
    if not data
        or not data.Enabled
    then
        return
    end
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "V3EntityJumpscare"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    gui.Parent = playerGui
    local flash = Instance.new("Frame")
    flash.Name = "Flash"
    flash.Size = UDim2.fromScale(4, 4)
    flash.BackgroundColor3 = GetColor(data.FlashColor)
    flash.BackgroundTransparency = 0
    flash.BorderSizePixel = 0
    flash.Parent = gui
    local image = Instance.new("ImageLabel")
    image.Name = "Face"
    image.AnchorPoint = Vector2.new(0.5, 0.5)
    image.Position = UDim2.fromScale(0.5, 0.5)
    image.BackgroundTransparency = 1
    image.ScaleType = Enum.ScaleType.Fit
    local startSize = data.StartSize or 0.2
    image.Size = UDim2.fromScale(startSize, startSize)
    image.Image = data.Image or config.FaceId
    image.Parent = gui
    local sound
    if typeof(data.Sound) == "string"
        and data.Sound ~= ""
    then
        sound = Instance.new("Sound")
        sound.Name = "JumpscareSound"
        sound.SoundId = data.Sound
        sound.Volume = data.Volume or 1
        sound.Looped = false
        sound.Parent = gui
        if data.PitchShiftEnabled then
            local pitch = Instance.new("PitchShiftSoundEffect")
            pitch.Octave = 1
            pitch.Parent = sound
        end
        sound:Play()
    end
    local duration = math.max(data.Duration or 0.6, 0.05)
    if data.FlashEnabled then
        local flashColor = GetColor(data.FlashColor)
        local black = Color3.new(0, 0, 0)
        flash.BackgroundColor3 = flashColor
        flash.BackgroundTransparency = 0
        task.spawn(function()
            local flashSpeed = math.max(data.FlashSpeed or 0.1, 0.01)
            local startTime = os.clock()
            local useColor = false
            while gui.Parent do
                local elapsed = os.clock() - startTime
                if elapsed >= duration then
                    break
                end
                useColor = not useColor
                flash.BackgroundColor3 = useColor and flashColor or black
                flash.BackgroundTransparency = 0
                task.wait(flashSpeed)
            end
        end)
    else
        flash.BackgroundTransparency = 1
    end
    local wiggleAngle = data.WiggleAngle or 15
    TweenService:Create(
        image,
        TweenInfo.new(duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
        { Size = UDim2.fromScale(1, 1) }
    ):Play()
    task.spawn(function()
        local startTime = os.clock()
        local direction = 1
        while gui.Parent do
            local elapsed = os.clock() - startTime
            local alpha = math.clamp(elapsed / duration, 0, 1)
            if alpha >= 1 then
                break
            end
            local fade = 1 - alpha
            local angle = wiggleAngle * fade * direction
            image.Rotation = angle
            local waitTime = 0.025 + alpha * 0.08
            task.wait(waitTime)
            direction = -direction
        end
        if image.Parent then
            image.Rotation = 0
        end
    end)
    task.wait(duration)
    SafeDestroy(gui)
end
local function NormalizeType(value, fallback)
    if typeof(value) ~= "string" or value == "" then return fallback end
    return value:upper():gsub("%s+", "-")
end
--// V3 → V2 config //--
local function BuildV2Config(config, model)
    local movementType = NormalizeType(
        config.Movement and config.Movement.Type,
        "NODE"
    )

    -- V2 skips its ENTIRE node system when Movement.FollowPlayer == true.
    --
    --   NON-NODE : V2 must not move it -> FollowPlayer = true for V2
    --   CHASER   : V2 must not move it -> FollowPlayer = true for V2
    --              (V3 owns CHASER movement; this is the first of the
    --               three V2 lockouts, see the header + PatchV2Source)
    --   NODE     : keeps its own FollowPlayer value (legacy compatible)
    local v2FollowPlayer =
        (config.Movement and config.Movement.FollowPlayer) == true
        or movementType == "NON-NODE"
        or movementType == "CHASER"

    return {
        Entity = {
            Name = config.EntityName or "CustomEntity",
            Asset = model,
            HeightOffset = config.HeightOffset or 0
        },
        Movement = {
            Speed = (config.Movement and config.Movement.Speed) or 100,
            Delay = (config.Movement and config.Movement.Delay) or 0,
            Reversed = (config.Movement and config.Movement.Reversed) or false,
            Type = (config.Movement and config.Movement.Type) or "NODE",
            FollowPlayer = v2FollowPlayer,
            FollowPlayerDespawnTime = (config.Movement and config.Movement.FollowPlayerDespawnTime) or 0
        },
        Damage = {
            Enabled = (config.Damage and config.Damage.Enabled)
                and NormalizeType(config.Damage and config.Damage.Type, "RANGE") == "RANGE",
            Type = (config.Damage and config.Damage.Type) or "RANGE",
            LookCone = (config.Damage and config.Damage.LookCone) or 70,
            Cooldown = (config.Damage and config.Damage.Cooldown) or 1,
            IgnoreHiding = (config.Damage and config.Damage.IgnoreHiding) or false,
            Range = (config.Damage and config.Damage.Range) or 10,
            Amount = (config.Damage and config.Damage.Amount) or 100
        },
        Lights = {
            Flicker = {
                Enabled = (config.Lights and config.Lights.Flicker and config.Lights.Flicker.Enabled) or false,
                Duration = (config.Lights and config.Lights.Flicker and config.Lights.Flicker.Duration) or 1
            },
            Shatter = (config.Lights and config.Lights.Shatter) or false,
            Repair = (config.Lights and config.Lights.Repair) or false
        },
        Earthquake = {
            Enabled = (config.Earthquake and config.Earthquake.Enabled) or false
        },
        CameraShake = {
            Enabled = (config.CameraShake and config.CameraShake.Enabled) or false,
            Range = (config.CameraShake and config.CameraShake.Range) or 100,
            Values = (config.CameraShake and config.CameraShake.Values) or { 1.5, 20, 0.1, 1 }
        },
        Crucifixion = {
            Type = (config.Crucifixion and config.Crucifixion.Type) or "Custom",
            Enabled = (config.Crucifixion and config.Crucifixion.Enabled) or false,
            Range = (config.Crucifixion and config.Crucifixion.Range) or 15,
            Resist = (config.Crucifixion and config.Crucifixion.Resist) or false,
            Break = (config.Crucifixion and config.Crucifixion.Break) or false
        },
        Rebounding = {
            Enabled = (config.Rebounding and config.Rebounding.Enabled) or false,
            Type = (config.Rebounding and config.Rebounding.Type) or "Normal",
            Min = (config.Rebounding and config.Rebounding.Min) or 1,
            Max = (config.Rebounding and config.Rebounding.Max) or 1,
            Delay = (config.Rebounding and config.Rebounding.Delay) or 2
        },
        Death = {
            Type = (config.Death and config.Death.Type) or "Guiding",
            Hints = (config.Death and config.Death.Hints) or {}
        }
    }
end
--// callbacks //--
local function SetupCallbacks(entity, config, assetList, spawnState)
    entity:SetCallback("OnSpawned", function()
        spawnState.Time = os.clock()
        EntityActive = true
        CurrentEntity = entity
        FarRushSoundInstance = nil
        NearRushSoundInstance = nil
        local model = entity.Model
        if not model then
            return
        end
        SetupFace(model, config)
        SetupAura(model, config)
        SetupLight(model, config.EntityLight, "EntityLight")
        SetupLight(model, config.EntityLamp2, "EntityLamp2")
        SetupEnvironment(config)
        PlaySpawnSound(config)
    end)
    entity:SetCallback(
        "OnStartMoving",
        function()
            if not EntityActive then
                return
            end

            local model = entity.Model or entity.model
            if not model then
                return
            end

            local movementType = NormalizeType(
                config.Movement and config.Movement.Type,
                "NODE"
            )

            local targetMode = NormalizeType(
                config.Movement and config.Movement.Target,
                "NONE"
            )

            -- A stationary NON-NODE entity does not pretend to be
            -- starting a V2 node run, so it does not emit rush audio.
            -- (CHASER always moves, so it always plays the far rush.)
            if movementType == "NON-NODE"
                and config.Movement
                and config.Movement.FollowPlayer ~= true
                and targetMode ~= "PLAYER"
            then
                return
            end

            PlayRushSound(
                model,
                config.FarRushSound,
                config.FarVolume,
                config.FarPlaybackSpeed,
                "FarRush",
                config.FarRollOffMaxDistance
            )
        end
    )
    entity:SetCallback("OnReachedNode", function(...)
        if not EntityActive then
            return
        end
    end)
    local LastNearRushRoom = nil
    entity:SetCallback("OnEnterRoom", function(room, firstTime)
        if not EntityActive then
            return
        end
        if not firstTime then
            return
        end
        local roomNumber = tonumber(room and room.Name)
        if roomNumber and LastNearRushRoom == roomNumber then
            return
        end
        LastNearRushRoom = roomNumber
        local model = entity.Model or entity.model
        if not model then
            return
        end
        PlayRushSound(
            model,
            config.NearRushSound,
            config.NearVolume,
            config.NearPlaybackSpeed,
            "NearRush",
            config.NearRollOffMaxDistance
        )
    end)
    entity:SetCallback("OnLookAt", function(...)
        if not EntityActive then
            return
        end
    end)
    entity:SetCallback("OnRebounding", function(...)
        if not EntityActive then
            return
        end
    end)
    entity:SetCallback("OnDespawning", function()
        FadeOutActiveSounds(0.9)
        RemoveEnvironment(config)
    end)
    entity:SetCallback("OnDespawned", function()
        EntityActive = false
        if CurrentEntity == entity then
            CurrentEntity = nil
        end
        RemoveEnvironment(config)
        StopAllActiveSounds()
        PlayDespawnSound(config)
        local ownedAssets = assetList
        task.delay(ASSET_CLEANUP_DELAY, function()
            CleanupAssetFiles(ownedAssets)
        end)
    end)
    entity:SetCallback("OnDamagePlayer", function(newHealth)
        if not EntityActive then
            return
        end
        local humanoid = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local health = tonumber(newHealth)
            or (humanoid and humanoid.Health)
            or 100
        if health <= 0 then
            if config.Jumpscare and config.Jumpscare.Enabled then
                task.spawn(function()
                    RunJumpscare(config)
                end)
            end
        end
    end)
end
--// V3 MOVEMENT + DAMAGE CONTROLLERS //--
local function GetRoot(model)
    return model and (model.PrimaryPart or model:FindFirstChild("Root", true) or model:FindFirstChildWhichIsA("BasePart", true))
end
local function GetPlayerRoot()
    local character = LocalPlayer.Character
    return character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart", true))
end
local function GetPlayerCamera()
    return workspace.CurrentCamera
end
local function IsBlocked(origin, target, entityModel, strictWalls)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    -- IMPORTANT:
    -- For LOOK_AND_HURT_OPPOSITE, walls must always protect the player.
    -- Do NOT exclude HidingSpots from the raycast in that mode, because
    -- doing so could let the detection ray pass through solid geometry.
    local filters = {
        LocalPlayer.Character,
        entityModel
    }

    if not strictWalls then
        for _, hidingSpot in ipairs(CollectionService:GetTagged("HidingSpot")) do
            table.insert(filters, hidingSpot)
        end
    end

    params.FilterDescendantsInstances = filters

    local direction = target - origin
    if direction.Magnitude <= 0.001 then
        return false
    end

    local hit = workspace:Raycast(origin, direction, params)
    return hit ~= nil
end

local function GetLookState(entityModel, range, cone, strictWalls)
    local camera = GetPlayerCamera()
    local root = GetRoot(entityModel)
    if not camera or not root then return nil end

    local cameraPosition = camera.CFrame.Position
    local targetPosition = root.Position
    local offset = targetPosition - cameraPosition
    local distance = offset.Magnitude

    if distance > range or distance <= 0.001 then
        return nil
    end

    -- strictWalls = true is used by LOOK_AND_HURT_OPPOSITE.
    -- If ANY raycast obstacle is between the camera and the entity,
    -- the entity is considered completely undetectable and cannot hurt.
    if IsBlocked(cameraPosition, targetPosition, entityModel, strictWalls) then
        return nil
    end

    local direction = offset.Unit
    local dot = math.clamp(camera.CFrame.LookVector:Dot(direction), -1, 1)
    local halfCone = math.rad(math.clamp(cone, 0, 180) * 0.5)

    return math.acos(dot) <= halfCone
end

local function DamageCustom(entity, config)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    if not config.Damage.Enabled then return end
    if not config.Damage.IgnoreHiding and character:GetAttribute("Hiding") then return end
    local now = os.clock()
    local cooldown = math.max(0, tonumber(config.Damage.Cooldown) or 1)
    entity.__V3LastDamage = entity.__V3LastDamage or 0
    if now - entity.__V3LastDamage < cooldown then return end
    local amount = math.max(0, tonumber(config.Damage.Amount) or 100)
    local newHealth = math.clamp(humanoid.Health - amount, 0, humanoid.MaxHealth)
    entity.__V3LastDamage = now
    humanoid.Health = newHealth
    pcall(function() entity:RunCallback("OnDamagePlayer", newHealth) end)
end
local function StartCustomDamage(entity, config)
    local damageType = NormalizeType(config.Damage and config.Damage.Type, "RANGE")
    if damageType ~= "LOOK_AND_HURT" and damageType ~= "LOOK_AND_HURT_OPPOSITE" then return end
    local model = entity.Model or entity.model
    if not model then return end
    model:SetAttribute("Damage", true)

    -- Fixed grace period (intentionally NOT configurable): look-based
    -- damage cannot start until 0.8s after the entity has spawned in the
    -- room, so a player who is already looking that way when it appears
    -- doesn't get hurt by accident. The clock starts right now, which is
    -- when the entity is placed in the room.
    local LOOK_DAMAGE_START_DELAY = 0.8
    local damageStartTime = os.clock() + LOOK_DAMAGE_START_DELAY

    task.spawn(function()
        while entity:IsAlive() and model.Parent do
            task.wait()

            if os.clock() < damageStartTime then
                continue
            end

            if model:GetAttribute("Paused")
                or model:GetAttribute("BeingBanished")
            then
                continue
            end

            local range = tonumber(config.Damage.Range) or 10
            local cone = tonumber(config.Damage.LookCone) or 70

            -- Both look-based mechanics are intentionally less punishing
            -- than ordinary RANGE damage.
            --
            -- LOOK_AND_HURT:
            --   default range = 8 studs
            --   default cone = 55 degrees
            --
            -- LOOK_AND_HURT_OPPOSITE:
            --   default range = 8 studs
            --   default cone = 55 degrees
            --   strict wall protection
            if damageType == "LOOK_AND_HURT"
                or damageType == "LOOK_AND_HURT_OPPOSITE"
            then
                -- LookRange wins if set, then Damage.Range, then the 8 stud default.
                -- (Previously Damage.Range was ignored here, so a stationary
                -- NON-NODE entity only ever hurt inside 8 studs.)
                range = tonumber(config.Damage.LookRange)
                    or tonumber(config.Damage.Range)
                    or 8
                cone = tonumber(config.Damage.LookCone) or 55
            end

            -- LOOK_AND_HURT_OPPOSITE uses strict wall protection.
            local strictWalls = damageType == "LOOK_AND_HURT_OPPOSITE"

            local lookState = GetLookState(
                model,
                range,
                cone,
                strictWalls
            )

            -- nil means:
            --   • out of range, OR
            --   • blocked by an obstacle/wall
            --
            -- In either case the opposite mechanic MUST NOT hurt.
            local shouldHurt = lookState ~= nil and (
                (damageType == "LOOK_AND_HURT" and lookState)
                or
                (damageType == "LOOK_AND_HURT_OPPOSITE" and not lookState)
            )

            if shouldHurt then
                -- Look-based damage gets its own debounce so it cannot repeatedly
                -- trigger faster than the configured look cooldown.
                local lookCooldown = tonumber(config.Damage.LookCooldown)
                    or (tonumber(config.Damage.Cooldown) or 1.5)

                local lastLookDamage = entity.__V3LastLookDamage or 0
                local now = os.clock()

                if now - lastLookDamage >= lookCooldown then
                    entity.__V3LastLookDamage = now
                    DamageCustom(entity, config)
                end
            end
        end
    end)
end
local function MoveDirect(model, target, speed, dt)
    local pivot = model:GetPivot()
    local offset = target - pivot.Position
    local distance = offset.Magnitude
    if distance <= 0.1 then return true end
    local step = math.min(distance, math.max(0, speed) * dt)
    local position = pivot.Position + offset.Unit * step
    model:PivotTo(CFrame.lookAt(position, position + offset.Unit))
    return step >= distance - 0.1
end
local function GetRoomCenterSpawnPosition(room, heightOffset)
    if not room then
        return nil
    end

    local center = room:GetBoundingBox().Position
    local floorPart = room:FindFirstChild(room.Name)

    -- V2 identifies the room floor through the part named after the room.
    -- Use that same floor part here so the NON-NODE spawn is actually on
    -- the current room's floor instead of floating at the model bounding-box center.
    if floorPart and floorPart:IsA("BasePart") then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = {floorPart}
        params.CollisionGroup = "BaseCheck"

        local hit = workspace:Raycast(
            center + Vector3.new(0, 100, 0),
            Vector3.new(0, -200, 0),
            params
        )

        if hit then
            center = hit.Position
        end
    end

    return center + Vector3.new(
        0,
        3 + (tonumber(heightOffset) or 0),
        0
    )
end

local GetPlayerRoomNumber

local function DespawnNonNode(entity, model)
    if not entity:IsAlive() or not model.Parent then
        return
    end

    if model:GetAttribute("Despawning") then
        return
    end

    model:SetAttribute("Despawning", true)

    pcall(function()
        entity:RunCallback("OnDespawning")
    end)

    pcall(function()
        entity:Despawn()
    end)
end

local function StartNonNodeMovement(entity, config)
    local model = entity.Model or entity.model
    if not model then
        return
    end

    local movement = config.Movement or {}
    local rooms = workspace:FindFirstChild("CurrentRooms")

    if not rooms then
        warn("V3 Non-Node: CurrentRooms missing.")
        return
    end

    local playerRoomNumber = GetPlayerRoomNumber()
    if playerRoomNumber == nil then
        warn("V3 Non-Node: could not determine player's current room.")
        return
    end

    local currentRoom = rooms:FindFirstChild(tostring(playerRoomNumber))

    if not currentRoom then
        warn(
            "V3 Non-Node: current room "
            .. tostring(playerRoomNumber)
            .. " was not found."
        )
        return
    end

    --==================================================--
    -- SPAWN IN THE CENTER OF THE PLAYER'S CURRENT ROOM
    --==================================================--

    local spawnPosition = GetRoomCenterSpawnPosition(
        currentRoom,
        config.HeightOffset
    )

    if spawnPosition then
        model:PivotTo(CFrame.new(spawnPosition))
    end

    pcall(function()
        model:SetAttribute("V3NonNodeRoom", playerRoomNumber)
        model:SetAttribute("V3NonNodeMovement", true)
    end)

    --==================================================--
    -- DESPAWN WHEN A NEW, PREVIOUSLY UNLOADED ROOM APPEARS
    --
    -- In DOORS, opening the next unopened door causes the new
    -- room to be inserted into CurrentRooms. Watching ChildAdded
    -- therefore lets NON-NODE disappear at door generation time,
    -- instead of waiting until the player physically enters it.
    --==================================================--

    local connections = {}
    entity.__V3NonNodeConnections = connections

    local function DisconnectAll()
        for _, connection in ipairs(connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        table.clear(connections)
    end

    local childConnection
    childConnection = rooms.ChildAdded:Connect(function(room)
        if not entity:IsAlive() or not model.Parent then
            DisconnectAll()
            return
        end

        local newRoomNumber = tonumber(room.Name)

        if newRoomNumber
            and newRoomNumber ~= playerRoomNumber
        then
            DisconnectAll()
            DespawnNonNode(entity, model)
        end
    end)

    table.insert(connections, childConnection)

    -- Fallback: if a game build updates CurrentRoom before/without
    -- CurrentRooms.ChildAdded, also despawn once the player advances.
    local attributeConnection
    attributeConnection = LocalPlayer:GetAttributeChangedSignal(
        "CurrentRoom"
    ):Connect(function()
        if not entity:IsAlive() or not model.Parent then
            DisconnectAll()
            return
        end

        local newRoomNumber = tonumber(
            LocalPlayer:GetAttribute("CurrentRoom")
        )

        if newRoomNumber
            and newRoomNumber ~= playerRoomNumber
        then
            DisconnectAll()
            DespawnNonNode(entity, model)
        end
    end)

    table.insert(connections, attributeConnection)

    --==================================================--
    -- OPTIONAL DIRECT MOVEMENT
    --
    -- NON-NODE itself does NOT force a chase.
    -- If FollowPlayer or Target = "PLAYER" is supplied, the
    -- entity independently moves toward the player without
    -- using V2's PathfindNodes.
    --==================================================--

    local targetMode = NormalizeType(
        movement.Target,
        "NONE"
    )

    if movement.FollowPlayer ~= true
        and targetMode ~= "PLAYER"
    then
        task.spawn(function()
            while entity:IsAlive()
                and model.Parent
            do
                task.wait(0.25)
            end

            DisconnectAll()
        end)

        return
    end

    local speed = tonumber(movement.Speed) or 100

    local movementConnection
    movementConnection = RunService.Heartbeat:Connect(function(dt)
        if not entity:IsAlive() or not model.Parent then
            pcall(function()
                movementConnection:Disconnect()
            end)
            return
        end

        if model:GetAttribute("Paused")
            or model:GetAttribute("BeingBanished")
        then
            return
        end

        local target = GetPlayerRoot()

        if target then
            MoveDirect(
                model,
                target.Position,
                speed,
                dt
            )
        end
    end)

    table.insert(connections, movementConnection)

    task.spawn(function()
        while entity:IsAlive()
            and model.Parent
        do
            task.wait(0.25)
        end

        DisconnectAll()
    end)
end
local function GetRoomNumber(room)
    return room and tonumber(room.Name) or nil
end
local function GetRoomAtPoint(position)
    local rooms = workspace:FindFirstChild("CurrentRooms")
    if not rooms then return nil end
    local whitelist = {}
    for _, room in ipairs(rooms:GetChildren()) do
        local floor = room:FindFirstChild(room.Name)
        if floor then whitelist[#whitelist + 1] = floor end
    end
    if #whitelist == 0 then return nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = whitelist
    params.CollisionGroup = "BaseCheck"
    local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -100, 0), params)
    return hit and hit.Instance and hit.Instance.Parent or nil
end

GetPlayerRoomNumber = function()
    local value = LocalPlayer:GetAttribute("CurrentRoom")
    local number = tonumber(value)
    if number then return number end
    local root = GetPlayerRoot()
    if not root then return nil end
    local room = GetRoomAtPoint and GetRoomAtPoint(root.Position) or nil
    return GetRoomNumber(room)
end
local function GetRoomNodes(room, reversed, height)
    local nodes = {}
    if not room then return nodes end
    local entrance = room:FindFirstChild("RoomEntrance")
    if entrance and entrance:IsA("BasePart") then
        local n = entrance:Clone(); n.Name = "0"; n.CFrame -= Vector3.new(0, 3, 0); nodes[#nodes + 1] = n
    end
    local folder = room:FindFirstChild("PathfindNodes") or room:FindFirstChild("Nodes")
    if folder then
        for _, node in ipairs(folder:GetChildren()) do if node:IsA("BasePart") then nodes[#nodes + 1] = node end end
    end
    local exit = room:FindFirstChild("RoomExit")
    if exit and exit:IsA("BasePart") then
        local n = exit:Clone(); n.Name = tostring(#nodes + 1); n.CFrame -= Vector3.new(0, 3, 0); nodes[#nodes + 1] = n
    end
    table.sort(nodes, function(a,b) return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0) end)
    if reversed then
        local out = {}
        for i = #nodes, 1, -1 do out[#out + 1] = nodes[i] end
        nodes = out
    end
    for _, node in ipairs(nodes) do node:SetAttribute("V3Room", GetRoomNumber(room)) end
    return nodes
end
local function FindEntityRoom(model)
    local root = GetRoot(model)
    if not root then return nil end
    local rooms = workspace:FindFirstChild("CurrentRooms")
    if not rooms then return nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    local whitelist = {}
    for _, room in ipairs(rooms:GetChildren()) do
        local floor = room:FindFirstChild(room.Name)
        if floor then whitelist[#whitelist + 1] = floor end
    end
    params.FilterDescendantsInstances = whitelist
    params.CollisionGroup = "BaseCheck"
    local hit = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -100, 0), params)
    if hit then return GetRoomNumber(hit.Instance.Parent) end
    return nil
end
local function BuildHybridRoute(entityRoom, targetRoom, model, reversed)
    local roomsFolder = workspace:FindFirstChild("CurrentRooms")
    if not roomsFolder or not entityRoom or not targetRoom or entityRoom == targetRoom then return {} end
    local route = {}
    local step = targetRoom > entityRoom and 1 or -1
    local first = roomsFolder:FindFirstChild(tostring(entityRoom))
    if first then
        local nodes = GetRoomNodes(first, reversed, 0)
        local position = model:GetPivot().Position
        local best = 1
        local bestDistance = math.huge
        for i, node in ipairs(nodes) do
            local d = (node.Position - position).Magnitude
            if d < bestDistance then best, bestDistance = i, d end
        end
        if step > 0 then
            for i = best, #nodes do route[#route + 1] = {Node=nodes[i], Room=entityRoom} end
        else
            for i = best, #nodes do route[#route + 1] = {Node=nodes[i], Room=entityRoom} end
        end
    end
    local room = entityRoom + step
    while (step > 0 and room <= targetRoom) or (step < 0 and room >= targetRoom) do
        local current = roomsFolder:FindFirstChild(tostring(room))
        if current then
            for _, node in ipairs(GetRoomNodes(current, reversed, 0)) do route[#route + 1] = {Node=node, Room=room} end
        end
        room += step
    end
    return route
end
--// LEGACY FollowPlayer MOVEMENT (Type = "NODE" + FollowPlayer = true) //--
-- Kept exactly as it was for backwards compatibility.
-- CHASER does NOT use this; CHASER has its own controller below.
local function StartHybridMovement(entity, config, spawnTime)
    local model = entity.Model or entity.model
    if not model then return end
    local movement = config.Movement or {}
    local despawnTime = tonumber(movement.FollowPlayerDespawnTime) or 0
    task.spawn(function()
        task.wait(tonumber(movement.Delay) or 0)
        local entityRoom = FindEntityRoom(model)
        local playerRoom = GetPlayerRoomNumber()
        local route, index = {}, 1
        local speed = tonumber(movement.Speed) or 100
        local reversed = movement.Reversed == true
        local function rebuild(target)
            route = BuildHybridRoute(entityRoom, target, model, reversed)
            index = 1
        end
        while entity:IsAlive() and model.Parent do
            task.wait()
            if despawnTime > 0 and os.clock() - spawnTime >= despawnTime then
                if not model:GetAttribute("Despawning") then
                    model:SetAttribute("Despawning", true)
                    pcall(function() entity:RunCallback("OnDespawning") end)
                    pcall(function() entity:Despawn() end)
                end
                break
            end
            if model:GetAttribute("Paused") then continue end
            playerRoom = GetPlayerRoomNumber()
            if not entityRoom or not playerRoom then continue end
            if entityRoom == playerRoom then
                local target = GetPlayerRoot()
                if target then MoveDirect(model, target.Position, speed, 1/60) end
                route, index = {}, 1
                continue
            end
            if #route == 0 or index > #route then rebuild(playerRoom) end
            local data = route[index]
            if data and data.Node then
                local reached = MoveDirect(model, data.Node.Position + Vector3.new(0, 3 + (tonumber(config.HeightOffset) or 0), 0), speed, 1/60)
                if reached then
                    pcall(function() entity:RunCallback("OnReachedNode", data.Node) end)
                    entityRoom = data.Room
                    index += 1
                end
            end
        end
    end)
end

--==================================================--
-- CHASER MOVEMENT
--
-- "CHASER" is the PUBLIC / CONFIGURATION name.
-- The INTERNAL implementation is a room-aware chase
-- controller that is the ONLY movement authority for
-- the entity (V2's node system is locked out, see the
-- header, BuildV2Config and PatchV2Source).
--
--   different room -> follow RoomEntrance / PathfindNodes /
--                     RoomExit through the loaded rooms
--   same room      -> direct chase toward the player
--   player moved   -> route rebuilt toward the new room
--
-- Room state is NEVER trusted after the fact: both the
-- entity's room and the player's room are re-derived from
-- world position every few frames, so stale room numbers
-- can't keep CHASER on nodes after it has entered the
-- player's room.
--==================================================--

local CHASER_REFRESH_INTERVAL = 0.05    -- how often rooms are re-detected
local CHASER_REBUILD_COOLDOWN = 0.25    -- min time between rebuilds of an empty/finished route
local CHASER_ENTER_ROOM_GRACE = 0.3     -- V2 gets this long to fire OnEnterRoom before V3 does
local CHASER_MAX_ROOM_SPAN = 200        -- sanity limit for route building

-- shared despawn helper (name is legacy; it is not NON-NODE specific)
local DespawnV3Entity = DespawnNonNode

-- Player room: geometric position first, CurrentRoom attribute as fallback,
-- last known room if neither is available (respawning, mid-air, etc).
local function GetChaserPlayerRoom(lastKnownRoom)
    local root = GetPlayerRoot()
    if root then
        local geometric = GetRoomNumber(GetRoomAtPoint(root.Position))
        if geometric then
            return geometric
        end
    end

    local attribute = tonumber(LocalPlayer:GetAttribute("CurrentRoom"))
    if attribute then
        return attribute
    end

    return lastKnownRoom
end

-- Picks where to join a node list so the entity doesn't run backwards.
-- nearest node, then skip to the next one if we've already passed it.
local function PickChaserStartIndex(nodes, position)
    if #nodes <= 1 then
        return 1
    end

    local best, bestDistance = 1, math.huge
    for i, node in ipairs(nodes) do
        local distance = (node.Position - position).Magnitude
        if distance < bestDistance then
            best, bestDistance = i, distance
        end
    end

    if best < #nodes then
        local segment = nodes[best + 1].Position - nodes[best].Position
        if segment:Dot(position - nodes[best].Position) > 0 then
            best += 1
        end
    end

    return best
end

-- Builds a route of { Node = BasePart, Room = number } entries.
--
--   entityRoom == nil  -> entity isn't over any room floor yet (it spawns
--                         at V2's official spawn position), so it joins the
--                         loaded rooms from the "behind" side: lowest loaded
--                         room, or highest when Movement.Reversed = true.
--
-- Node ORDER always follows the direction of travel (ascending toward a
-- higher player room, descending toward a lower one). Movement.Reversed
-- only affects the spawn side described above.
--
-- The target room only contributes its doorway node: as soon as the entity
-- is really standing inside the player's room, the controller stops using
-- nodes and switches to the direct chase.
local function BuildChaserRoute(model, entityRoom, targetRoom, reversedSpawn, heightOffset)
    local roomsFolder = workspace:FindFirstChild("CurrentRooms")
    local root = GetRoot(model)
    if not roomsFolder or not root or not targetRoom then
        return {}
    end

    local startUnknown = entityRoom == nil

    if startUnknown then
        local lowest, highest = nil, nil
        for _, room in ipairs(roomsFolder:GetChildren()) do
            local number = tonumber(room.Name)
            if number then
                lowest = lowest and math.min(lowest, number) or number
                highest = highest and math.max(highest, number) or number
            end
        end
        if not lowest then
            return {}
        end
        entityRoom = reversedSpawn and highest or lowest
    elseif entityRoom == targetRoom then
        return {}
    end

    if math.abs(targetRoom - entityRoom) > CHASER_MAX_ROOM_SPAN then
        return {}
    end

    local step = targetRoom >= entityRoom and 1 or -1
    local travelReversed = step < 0
    local flatPosition = root.Position - Vector3.new(0, 3 + (tonumber(heightOffset) or 0), 0)

    local route = {}
    local room = entityRoom

    while true do
        local roomModel = roomsFolder:FindFirstChild(tostring(room))

        if roomModel then
            local nodes = GetRoomNodes(roomModel, travelReversed, 0)
            local first, last = 1, #nodes

            if room == targetRoom then
                last = math.min(1, #nodes)
            elseif room == entityRoom and not startUnknown then
                first = PickChaserStartIndex(nodes, flatPosition)
            end

            for i = first, last do
                route[#route + 1] = { Node = nodes[i], Room = room }
            end
        end

        if room == targetRoom then
            break
        end

        room += step
    end

    return route
end

-- Mirrors V2's own room-entry bookkeeping so OnEnterRoom fires exactly once
-- per room. The shared LastEnteredRoom attribute is the gate, so V2's own
-- room detection and this fallback can never double-fire.
local function NotifyChaserRoomEntered(entity, model, room)
    local roomNumber = GetRoomNumber(room)
    if not roomNumber or roomNumber < 0 then
        return
    end

    if model:GetAttribute("LastEnteredRoom") == roomNumber then
        return
    end

    model:SetAttribute("LastEnteredRoom", roomNumber)

    local roomsEntered = model:FindFirstChild("RoomsEntered")
    if not roomsEntered then
        return
    end

    local firstTime = roomsEntered:GetAttribute(room.Name) == nil

    task.spawn(function()
        pcall(function()
            entity:RunCallback("OnEnterRoom", room, firstTime)
        end)
    end)

    if firstTime then
        roomsEntered:SetAttribute(room.Name, true)
    end
end

local function StartChaserMovement(entity, config, spawnTime)
    local model = entity.Model or entity.model
    if not model then
        return
    end

    local movement = config.Movement or {}

    -- Second V2 lockout (the first is FollowPlayer = true in BuildV2Config,
    -- the third is the PatchV2Source attribute check). Also set in
    -- Brain.Spawn BEFORE entity:Run(); repeated here so the controller is
    -- self-contained.
    pcall(function()
        model:SetAttribute("V3ChaserMovement", true)
    end)

    -- FollowPlayer / Target only identify WHO is chased. CHASER always
    -- chases the player and owns the movement itself.
    local targetMode = NormalizeType(movement.Target, "PLAYER")
    if targetMode ~= "PLAYER" then
        warn("V3 Chaser: unsupported Target '" .. tostring(movement.Target) .. "', chasing the PLAYER instead.")
    end

    -- Speed is used raw (studs/second) for BOTH node travel and the direct
    -- chase. It is not passed through V2's 0.65 speed scaling because V2 is
    -- not moving this entity.
    local speed = math.max(0, tonumber(movement.Speed) or 19)
    local delay = math.max(0, tonumber(movement.Delay) or 0)
    local despawnTime = tonumber(movement.FollowPlayerDespawnTime) or 0
    local reversed = movement.Reversed == true
    local heightOffset = tonumber(config.HeightOffset) or 0

    -- entity:Run() blocks for V2's Movement.Delay before returning, so this
    -- is normally already 0; it also covers builds where Run doesn't yield.
    local moveStart = os.clock() + math.max(0, delay - (os.clock() - spawnTime))

    local entityRoom = nil        -- room the entity is actually in (geometric)
    local playerRoom = nil        -- room the player is actually in
    local nodeRoomHint = nil      -- room of the last reached node (fallback only)

    local route, routeIndex, routeTargetRoom = {}, 1, nil
    local lastRefresh, lastRebuild = 0, 0
    local pendingRoomNumber, pendingSince = nil, 0
    local connection

    local function DirectChase(playerRoot, dt)
        MoveDirect(
            model,
            playerRoot.Position + Vector3.new(0, heightOffset, 0),
            speed,
            dt
        )
    end

    connection = RunService.Heartbeat:Connect(function(dt)
        if not entity:IsAlive() or not model.Parent then
            connection:Disconnect()
            return
        end

        local now = os.clock()

        -- despawn timer keeps counting while paused, same as legacy movement
        if despawnTime > 0 and now - spawnTime >= despawnTime then
            connection:Disconnect()
            DespawnV3Entity(entity, model)
            return
        end

        if now < moveStart then
            return
        end

        if model:GetAttribute("Paused")
            or model:GetAttribute("BeingBanished")
            or model:GetAttribute("Despawning")
        then
            return
        end

        local root = GetRoot(model)
        local playerRoot = GetPlayerRoot()
        if not root or not playerRoot then
            return
        end

        --// ROOM REFRESH (world position, never just stored state) //--
        if now - lastRefresh >= CHASER_REFRESH_INTERVAL then
            lastRefresh = now

            local entityRoomModel = GetRoomAtPoint(root.Position)
            local geometricEntityRoom = GetRoomNumber(entityRoomModel)

            entityRoom = geometricEntityRoom or nodeRoomHint or entityRoom
            playerRoom = GetChaserPlayerRoom(playerRoom)

            -- OnEnterRoom fallback: V2 normally fires it itself because its
            -- room detection watches the model position. If it hasn't after a
            -- short grace period, V3 fires it (same LastEnteredRoom gate).
            if entityRoomModel
                and geometricEntityRoom
                and geometricEntityRoom ~= model:GetAttribute("LastEnteredRoom")
            then
                if pendingRoomNumber ~= geometricEntityRoom then
                    pendingRoomNumber = geometricEntityRoom
                    pendingSince = now
                elseif now - pendingSince >= CHASER_ENTER_ROOM_GRACE then
                    pendingRoomNumber = nil
                    NotifyChaserRoomEntered(entity, model, entityRoomModel)
                end
            else
                pendingRoomNumber = nil
            end

            model:SetAttribute("V3ChaserEntityRoom", entityRoom)
            model:SetAttribute("V3ChaserPlayerRoom", playerRoom)
        end

        --// player room unknown: nothing to route toward, chase directly //--
        if playerRoom == nil then
            DirectChase(playerRoot, dt)
            return
        end

        --// SAME ROOM: stop following nodes, chase the player //--
        if entityRoom ~= nil and entityRoom == playerRoom then
            if #route > 0 or routeTargetRoom ~= nil then
                route, routeIndex, routeTargetRoom = {}, 1, nil
            end
            DirectChase(playerRoot, dt)
            return
        end

        --// DIFFERENT ROOM: (re)build the route if needed //--
        local playerRoomChanged = routeTargetRoom ~= playerRoom
        local routeFinished = routeIndex > #route

        if playerRoomChanged
            or (routeFinished and now - lastRebuild >= CHASER_REBUILD_COOLDOWN)
        then
            route = BuildChaserRoute(model, entityRoom, playerRoom, reversed, heightOffset)
            routeIndex = 1
            routeTargetRoom = playerRoom
            lastRebuild = now
        end

        --// FOLLOW NODES //--
        local data = route[routeIndex]

        if data and data.Node then
            local reached = MoveDirect(
                model,
                data.Node.Position + Vector3.new(0, 3 + heightOffset, 0),
                speed,
                dt
            )

            if reached then
                pcall(function()
                    entity:RunCallback("OnReachedNode", data.Node)
                end)

                nodeRoomHint = data.Room
                routeIndex += 1

                -- re-detect rooms on the very next frame so entering the
                -- player's room switches to the direct chase immediately
                lastRefresh = 0
            end
        else
            -- no usable route (rooms missing / nothing to walk): fall back to
            -- a direct chase instead of freezing in place
            DirectChase(playerRoot, dt)
        end
    end)

    entity.__V3ChaserConnection = connection
end

local function PlayBanishSound(model, config)
    local soundConfig = config.BanishmentSound or {}
    local id = soundConfig.Id or "rbxassetid://139310882854462"
    local speed = tonumber(soundConfig.PlaybackSpeed) or 0.8
    local sound = Instance.new("Sound")
    sound.Name = "V3BanishmentSound"
    sound.SoundId = tostring(id):match("^rbxassetid://") and tostring(id) or "rbxassetid://" .. tostring(id)
    sound.PlaybackSpeed = speed
    sound.Volume = tonumber(soundConfig.Volume) or 1
    sound.Looped = false
    sound.Parent = FindFacePart(model) or model
    sound:Play()
    sound.Ended:Connect(function() sound:Destroy() end)
end
local function StartV3Mechanics(entity, config, spawnTime)
    local model = entity.Model or entity.model
    if not model then return end
    local movementType = NormalizeType(config.Movement and config.Movement.Type, "NODE")

    -- ONE movement authority per type:
    --   CHASER   -> V3 room-aware chase controller (V2 locked out)
    --   NON-NODE -> V3 non-node controller (V2 nodes skipped)
    --   NODE     -> V2 nodes (legacy FollowPlayer = true still uses the
    --               old V3 hybrid controller)
    -- CHASER is checked FIRST so it can never fall into the hybrid branch.
    if movementType == "CHASER" then
        StartChaserMovement(entity, config, spawnTime)
    elseif movementType == "NON-NODE" then
        pcall(function() model:SetAttribute("V3NonNodeMovement", true) end)
        StartNonNodeMovement(entity, config)
    elseif config.Movement and config.Movement.FollowPlayer == true then
        StartHybridMovement(entity, config, spawnTime)
    end
    StartCustomDamage(entity, config)
    local banished = false
    task.spawn(function()
        while entity:IsAlive() and model.Parent do
            task.wait()
            local value = model:GetAttribute("BeingBanished") == true
            if value and not banished then
                banished = true
                PlayBanishSound(model, config)
            elseif not value then
                banished = false
            end
        end
    end)
end
--// SPAWN //--
function Brain.Spawn(config)
    if typeof(config) ~= "table" then
        error("V3 Brain: Spawn requires " .. "a config table.")
    end
    if CurrentEntity then
        pcall(function()
            CurrentEntity:Despawn()
        end)
        CurrentEntity = nil
        EntityActive = false
    end
    StopAllActiveSounds()
    local model = PrepareModel(config)
    local assetList = ResolveConfigAssets(config)
    local v2Config = BuildV2Config(config, model)
    local ok, entity = pcall(function()
        return Original:Create(v2Config)
    end)
    if not ok
        or not entity
    then
        CleanupAssetFiles(assetList)
        error("V3 Brain: V2 Create failed:\n" .. tostring(entity))
    end
    local spawnState = { Time = os.clock() }
    SetupCallbacks(entity, config, assetList, spawnState)
    model = entity.Model
        or entity.model
        or model

    -- CHASER lock: mark the model BEFORE V2 runs so the patched V2 node
    -- system sees the attribute and never moves this entity.
    if NormalizeType(config.Movement and config.Movement.Type, "NODE") == "CHASER" then
        model:SetAttribute("V3ChaserMovement", true)
    end

    local runOk, runError = pcall(function()
        entity:Run()
    end)
    if not runOk then
        CleanupAssetFiles(assetList)
        error("V3 Brain: entity Run failed:\n" .. tostring(runError))
    end
    StartV3Mechanics(entity, config, spawnState.Time)
    return entity
end
function Brain.GetCurrentEntity()
    return CurrentEntity
end
function Brain.IsActive()
    return EntityActive
end
function Brain.Despawn()
    local entity = CurrentEntity
    if entity then
        pcall(function()
            entity:Despawn()
        end)
    end
    EntityActive = false
    CurrentEntity = nil
    StopAllActiveSounds()
end
getgenv().VynixuEntitySpawnerV3 = Brain
return Brain