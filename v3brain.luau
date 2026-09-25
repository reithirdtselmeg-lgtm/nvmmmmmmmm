--// V3 ENTITY BRAIN //--
--// made by: 𝕝𝕦𝕟𝕒𝕣𝕓𝕣𝕖𝕓𝕖𝕒𝕦𝕥𝕪 𝕒𝕜𝕒 𝕖𝕝_𝕧𝕚𝕣𝕖𝕩𝕦𝕤!! //--

--// RETURN ONLY IF A VALID V3 BRAIN ALREADY EXISTS //--

local ExistingV3 = getgenv().VynixuEntitySpawnerV3

if ExistingV3
    and typeof(ExistingV3) == "table"
    and typeof(ExistingV3.Spawn) == "function"
then
    return ExistingV3
end

-- Old/incomplete V3 instance detected.
-- Clear it so this version can initialize properly.
getgenv().VynixuEntitySpawnerV3 = nil

--// Services //--

local Players = game:GetService("Players")
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

    local cleanUrl = url:match("^[^?#]+") or url
    local extension = cleanUrl:match("%.([%w]+)$")

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
    local randomPart = tostring(math.random(100000, 999999))
        .. "_"
        .. tostring(math.floor(os.clock() * 100000))

    return ASSET_FOLDER .. "/V3_" .. randomPart .. "." .. extension
end

local function DownloadExternalAsset(url, fallbackExtension)
    if not IsExternalUrl(url) then
        return url, nil
    end

    if not ExternalAssetFunctions.HttpGet
        or not ExternalAssetFunctions.WriteFile
        or not ExternalAssetFunctions.GetCustomAsset then

        warn("V3 Brain: external asset requires HttpGet, writefile, and getcustomasset.")
        return nil, nil
    end

    if not EnsureAssetFolder() then
        warn("V3 Brain: failed to prepare asset folder.")
        return nil, nil
    end

    local ok, data = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok or typeof(data) ~= "string" or #data == 0 then
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

    if not customOk or typeof(customAsset) ~= "string" or customAsset == "" then
        SafeDeleteFile(path)
        warn("V3 Brain: getcustomasset failed:\n" .. path)
        return nil, nil
    end

    return customAsset, path
end

local function ResolveAsset(value, fallbackExtension, assetList)
    if typeof(value) ~= "string" or value == "" then
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
            if i > 3 then break end
            if typeof(auraData) == "table" and auraData.Id then
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

    --[[
        IMPORTANT:

        Do NOT splice a replacement function into the V2 source.

        V3 FollowPlayer entities use StartHybridMovement()
        for their actual movement, so replacing the entire
        V2 EntityMoveTo function is unnecessary and can cause
        patched-source syntax errors if the V2 source changes.

        We only make small, exact compatibility patches here.
    ]]

    local patchedSource = source

    --// Callback compatibility //--

    local callbackSource, callbackCount =
        patchedSource:gsub(
            '"OnReachNode"',
            '"OnReachedNode"'
        )

    patchedSource = callbackSource

    if callbackCount == 0 then
        warn(
            "V3 Brain: " ..
            "'OnReachNode' -> 'OnReachedNode' " ..
            "patch matched 0 occurrences."
        )
    end

    --// Despawn movement speed //--

    local despawnPattern =
        'EntityMoveTo%(model, model:GetPivot%(%) %- Vector3%.new%(0, 300, 0%), config%.Movement%.Speed%)'

    local despawnReplacement =
        'EntityMoveTo(model, model:GetPivot() - Vector3.new(0, 300, 0), 60)'

    local despawnSource, despawnCount =
        patchedSource:gsub(
            despawnPattern,
            despawnReplacement
        )

    patchedSource = despawnSource

    if despawnCount == 0 then
        warn(
            "V3 Brain: V2 despawn movement patch matched 0 occurrences."
        )
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

        -- Cache-buster so the executor cannot reuse
        -- an older/truncated HTTP response.
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

            -- The current V2 source should end with Module.
            -- This catches a truncated response before loadstring.
            local trimmed = source:gsub("%s+$", "")

            if trimmed:match("return%s+Module%s*$") then
                return source
            end

            lastError =
                "V2 source did not end with 'return Module'."
        else
            lastError =
                "V2 HTTP response was invalid or suspiciously short."
        end

        task.wait(0.25)
    end

    error(
        "V3 Brain: failed to download a complete V2 source.\n"
        .. tostring(lastError)
    )
end

do

    local source = DownloadV2Source()

    print(
        "V3 Brain: downloaded V2 source:",
        #source,
        "characters"
    )

    local patchOk, patchedSource = pcall(function()
        return PatchV2Source(source)
    end)

    if not patchOk then
        error(
            "V3 Brain: failed to patch V2 source:\n"
            .. tostring(patchedSource)
        )
    end

    print(
        "V3 Brain: patched V2 source:",
        #patchedSource,
        "characters"
    )

    --// Compile //--

    local compileOk, V2Function = pcall(function()

        local fn, err = loadstring(patchedSource)

        if not fn then
            error(
                "V3 Brain: patched V2 COMPILE ERROR:\n"
                .. tostring(err)
            )
        end

        return fn
    end)

    if not compileOk then
        error(tostring(V2Function))
    end

    --// Execute //--

    local runOk, result = pcall(function()
        return V2Function()
    end)

    if not runOk then
        error(
            "V3 Brain: patched V2 EXECUTION ERROR:\n"
            .. tostring(result)
        )
    end

    if typeof(result) ~= "table" then
        error(
            "V3 Brain: patched V2 returned "
            .. typeof(result)
            .. " instead of a table."
        )
    end

    if typeof(result.Create) ~= "function" then
        error(
            "V3 Brain: V2 loaded, but Create is missing."
        )
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

--// active sounds //--

local ActiveSounds = {}

local function SafeDestroy(instance)
    if instance then
        pcall(function()
            instance:Destroy()
        end)
    end
end

local function StopSound(sound)
    if sound then
        pcall(function()
            sound:Stop()
        end)
        SafeDestroy(sound)
    end
end

local function StopAllActiveSounds()
    for sound, _ in pairs(ActiveSounds) do
        StopSound(sound)
    end
    table.clear(ActiveSounds)
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
    if not facePart then return end

    local faceId = config.FaceId
    if typeof(faceId) ~= "string" or faceId == "" then return end

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
    if not root or typeof(config.Auras) ~= "table" or #config.Auras == 0 then
        return
    end

    local firstAura = config.Auras[1]
    if typeof(firstAura) ~= "table" or typeof(firstAura.Id) ~= "string" or firstAura.Id == "" then
        warn("V3 Brain: Aura #1 must have a valid Id.")
        return
    end

    if firstAura.Color == nil then
        warn("V3 Brain: Aura #1 MUST define the master Color.")
        return
    end

    local masterColor = GetColor(firstAura.Color)
    local masterColorSequence = ColorSequence.new(masterColor)

    for index = 1, math.min(#config.Auras, 3) do
        local auraData = config.Auras[index]
        if typeof(auraData) == "table" and typeof(auraData.Id) == "string" and auraData.Id ~= "" then
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
    if not root then return end

    local oldLight = root:FindFirstChild(name)
    if oldLight then
        SafeDestroy(oldLight)
    end

    if not data or not data.Enabled then
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
    if not data or not data.Enabled then return end

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
    if not effect then return end

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
    if not parent or typeof(soundId) ~= "string" or soundId == "" then
        return nil
    end

    local sound = Instance.new("Sound")
    sound.Name = name or "V3Sound"
    sound.SoundId = soundId
    sound.Volume = volume or 1
    sound.Looped = looped == true
    sound.PlaybackSpeed = playbackSpeed or 1
    sound.Parent = parent

    return sound
end

--// spawn sound //--

local function PlaySpawnSound(config)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end

    local sound = CreateSound(
        playerGui,
        config.SpawnSound,
        config.SpawnVolume,
        config.SpawnPlaybackSpeed,
        "V3SpawnSound",
        false
    )

    if not sound then return end

    sound:Play()

    task.delay(config.SpawnSoundTimeout or 5, function()
        SafeDestroy(sound)
    end)
end

--// rush sounds //--

local function PlayRushSound(
    model,
    soundId,
    volume,
    playbackSpeed,
    name,
    rollOffMaxDistance
)
    if not model then
        return
    end

    local facePart = model:FindFirstChild("FacePart", true)

    if not facePart then
        return
    end

    local sound = CreateSound(
        facePart,
        soundId,
        volume,
        playbackSpeed,
        name,
        true
    )

    if not sound then
        return
    end

    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = 5
    sound.RollOffMaxDistance = rollOffMaxDistance or 240

    ActiveSounds[sound] = true

    sound:Play()
end

local function FadeOutActiveSounds(duration)
    duration = math.max(tonumber(duration) or 3, 0)

    local soundsToFade = {}

    for sound, _ in pairs(ActiveSounds) do
        table.insert(soundsToFade, sound)
    end

    table.clear(ActiveSounds)

    for _, sound in ipairs(soundsToFade) do
        if sound and sound.Parent then
            local tween = TweenService:Create(
                sound,
                TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
                { Volume = 0 }
            )

            tween:Play()

            task.delay(duration, function()
                SafeDestroy(sound)
            end)
        end
    end
end

--// despawn sound //--

local function PlayDespawnSound(config)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end

    local sound = CreateSound(
        playerGui,
        config.DespawnSound,
        config.DespawnVolume,
        config.DespawnPlaybackSpeed,
        "V3DespawnSound",
        false
    )

    if not sound then return end

    sound:Play()

    task.delay(config.DespawnSoundTimeout or 5, function()
        SafeDestroy(sound)
    end)
end

--// preload //--

local function Preload(config)
    local assets = {}

    local function AddAsset(id, className)
        if typeof(id) ~= "string" or id == "" then return end

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
            if i > 3 then break end
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
    if not data or not data.Enabled then return end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end

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
    if typeof(data.Sound) == "string" and data.Sound ~= "" then
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
                if elapsed >= duration then break end

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
            if alpha >= 1 then break end

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

--// V3 → V2 config //--

local function BuildV2Config(config, model)
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
            FollowPlayer = (config.Movement and config.Movement.FollowPlayer) == true,
            FollowPlayerDespawnTime = (config.Movement and config.Movement.FollowPlayerDespawnTime) or 0
        },
        Damage = {
            Enabled = (config.Damage and config.Damage.Enabled) or false,
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
            Values = (config.CameraShake and config.CameraShake.Values) or {1.5, 20, 0.1, 1}
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
            Type =
                (config.Death and config.Death.Type)
                or "Guiding",

            Hints =
                (config.Death and config.Death.Hints)
                or {},

            Cause = (
                config.Death
                and typeof(config.Death.Cause) == "string"
                and config.Death.Cause ~= ""
                and config.Death.Cause
            ) or "An entity killed you."
        }
    }
end

--// callbacks //--

local function SetupCallbacks(
    entity,
    config,
    assetList,
    spawnState
)

    entity:SetCallback("OnSpawned", function()
        spawnState.Time = os.clock()
        EntityActive = true
        CurrentEntity = entity

        local model = entity.Model
        if not model then return end

        SetupFace(model, config)
        SetupAura(model, config)
        SetupLight(model, config.EntityLight, "EntityLight")
        SetupLight(model, config.EntityLamp2, "EntityLamp2")
        SetupEnvironment(config)
        PlaySpawnSound(config)
    end)

    entity:SetCallback("OnStartMoving", function()
        local model = entity.Model
        if not model then return end

PlayRushSound(
    model,
    config.FarRushSound,
    config.FarVolume,
    config.FarPlaybackSpeed,
    "FarRush",
    config.FarRollOffMaxDistance
)
end) 

    entity:SetCallback("OnReachedNode", function(...)
        if not EntityActive then return end
    end)

    entity:SetCallback("OnEnterRoom", function(room, firstTime)
        if not EntityActive then return end

        local model = entity.Model
        if not model then return end

        if firstTime then
PlayRushSound(
    model,
    config.NearRushSound,
    config.NearVolume,
    config.NearPlaybackSpeed,
    "NearRush",
    config.NearRollOffMaxDistance
)
        end
    end)

    entity:SetCallback("OnLookAt", function(...)
        if not EntityActive then return end
    end)

    entity:SetCallback("OnRebounding", function(...)
        if not EntityActive then return end
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
        PlayDespawnSound(config)

        local ownedAssets = assetList
        task.delay(ASSET_CLEANUP_DELAY, function()
            CleanupAssetFiles(ownedAssets)
        end)
    end)

    entity:SetCallback("OnDamagePlayer", function(newHealth)
        if not EntityActive then return end

        if config.Jumpscare and config.Jumpscare.Enabled then
            task.spawn(function()
                RunJumpscare(config)
            end)
        end
    end)
end

--// V3 FOLLOW PLAYER / NODE HYBRID //--

local function StartHybridMovement(entity, config, spawnTime)
    if not config.Movement or config.Movement.FollowPlayer ~= true then
        return
    end

    local model = entity.Model or entity.model
    if not model then
        warn("V3 HybridMovement: entity model missing")
        return
    end

    local CurrentRooms = workspace:FindFirstChild("CurrentRooms")
    if not CurrentRooms then
        warn("V3 HybridMovement: CurrentRooms missing")
        return
    end

    local player = Players.LocalPlayer

    local speed = tonumber(config.Movement.Speed) or 100
    local despawnTime =
        tonumber(config.Movement.FollowPlayerDespawnTime) or 0

    local movementDelay =
        tonumber(config.Movement.Delay) or 0

    spawnTime = tonumber(spawnTime) or os.clock()

    --// PLAYER ROOT //--

    local function GetPlayerRoot()
        local character = player.Character
        if not character then
            return nil
        end

        return character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("Root")
    end

    --// ROOM NUMBER //--

    local function GetRoomNumber(room)
        if not room then
            return nil
        end

        return tonumber(room.Name)
    end

    --// ROOM AT POSITION //--

    local function GetRoomAtPosition(position)
        local rooms = CurrentRooms:GetChildren()

        table.sort(rooms, function(a, b)
            return (tonumber(a.Name) or math.huge)
                < (tonumber(b.Name) or math.huge)
        end)

        for _, room in ipairs(rooms) do
            local roomNumber = tonumber(room.Name)

            if roomNumber then
                local roomModel = room:FindFirstChild(room.Name)

                if roomModel then
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Include
                    params.FilterDescendantsInstances = {roomModel}
                    params.CollisionGroup = "BaseCheck"

                    local result = workspace:Raycast(
                        position + Vector3.new(0, 5, 0),
                        Vector3.new(0, -100, 0),
                        params
                    )

                    if result then
                        return room
                    end
                end
            end
        end

        return nil
    end

    --// PLAYER ROOM //--

    local function GetPlayerRoom()
        local root = GetPlayerRoot()
        if not root then
            return nil
        end

        local currentRoom = player:GetAttribute("CurrentRoom")

        if currentRoom then
            local room = CurrentRooms:FindFirstChild(
                tostring(currentRoom)
            )

            if room then
                return room
            end
        end

        return GetRoomAtPosition(root.Position)
    end

    --// ROOM NODES //--

    local function GetNodesFromRoom(room)
        local nodes = {}

        if not room then
            return nodes
        end

        -- ROOM ENTRANCE

        local roomEntrance = room:FindFirstChild("RoomEntrance")

        if roomEntrance then
            local node = roomEntrance:Clone()

            node.Name = "0"
            node.CFrame -= Vector3.new(0, 3, 0)

            nodes[#nodes + 1] = node
        end

        -- PATHFIND NODES

        local nodesFolder =
            room:FindFirstChild("PathfindNodes")
            or room:FindFirstChild("Nodes")

        if nodesFolder then
            local roomNodes = nodesFolder:GetChildren()

            table.sort(roomNodes, function(a, b)
                return (tonumber(a.Name) or math.huge)
                    < (tonumber(b.Name) or math.huge)
            end)

            for _, node in ipairs(roomNodes) do
                if node:IsA("BasePart") then
                    nodes[#nodes + 1] = node
                end
            end
        end

        -- ROOM EXIT

        local roomExit = room:FindFirstChild("RoomExit")

        if roomExit then
            local node = roomExit:Clone()

            node.Name = tostring(#nodes + 1)
            node.CFrame -= Vector3.new(0, 3, 0)

            nodes[#nodes + 1] = node
        end

        return nodes
    end

    --// NODE POSITION //--

    local function GetNodePosition(node)
        return (
            node.CFrame
            + Vector3.new(
                0,
                3 + (tonumber(config.HeightOffset) or 0),
                0
            )
        ).Position
    end

    --// INITIAL ENTITY ROOM //--

    local function GetEntityRoom()
        if not model.Parent then
            return nil
        end

        local position = model:GetPivot().Position

        local room = GetRoomAtPosition(position)

        if room then
            return room
        end

        -- Fallback: nearest node

        local nearestRoom = nil
        local nearestDistance = math.huge

        for _, candidateRoom in ipairs(CurrentRooms:GetChildren()) do
            if tonumber(candidateRoom.Name) then
                local nodes = GetNodesFromRoom(candidateRoom)

                for _, node in ipairs(nodes) do
                    local nodePosition = GetNodePosition(node)
                    local distance =
                        (nodePosition - position).Magnitude

                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestRoom = candidateRoom
                    end
                end
            end
        end

        if nearestRoom and nearestDistance <= 150 then
            return nearestRoom
        end

        return nil
    end

    --// ORDERED ROOMS //--

    local function GetOrderedRooms()
        local rooms = {}

        for _, room in ipairs(CurrentRooms:GetChildren()) do
            if tonumber(room.Name) then
                rooms[#rooms + 1] = room
            end
        end

        table.sort(rooms, function(a, b)
            return tonumber(a.Name) < tonumber(b.Name)
        end)

        return rooms
    end

    --// BUILD ROUTE //--

    local function BuildRoute(
        startRoomNumber,
        targetRoomNumber,
        entityPosition
    )
        local route = {}

        if not startRoomNumber or not targetRoomNumber then
            return route
        end

        if startRoomNumber == targetRoomNumber then
            return route
        end

        local rooms = GetOrderedRooms()
        local roomMap = {}

        for _, room in ipairs(rooms) do
            local number = GetRoomNumber(room)

            if number then
                roomMap[number] = room
            end
        end

        local step =
            targetRoomNumber > startRoomNumber
            and 1
            or -1

        --// STARTING ROOM //--

        local startRoom = roomMap[startRoomNumber]

        if startRoom then
            local nodes = GetNodesFromRoom(startRoom)

            if #nodes > 0 then
                local nearestIndex = 1

                if entityPosition then
                    local nearestDistance = math.huge

                    for i, node in ipairs(nodes) do
                        local nodePosition =
                            GetNodePosition(node)

                        local distance =
                            (nodePosition - entityPosition).Magnitude

                        if distance < nearestDistance then
                            nearestDistance = distance
                            nearestIndex = i
                        end
                    end
                end

                if step > 0 then
                    for i = nearestIndex, #nodes do
                        route[#route + 1] = {
                            Node = nodes[i],
                            RoomNumber = startRoomNumber
                        }
                    end
                else
                    for i = nearestIndex, 1, -1 do
                        route[#route + 1] = {
                            Node = nodes[i],
                            RoomNumber = startRoomNumber
                        }
                    end
                end
            end
        end

        --// FOLLOW LOADED ROOMS ONLY //--

        local currentRoomNumber =
            startRoomNumber + step

        while true do

            -- IMPORTANT:
            -- Stop if the requested room isn't loaded.
            --
            -- This prevents an infinite loop when the player
            -- enters a room that CurrentRooms has not generated yet.

            local room = roomMap[currentRoomNumber]

            if not room then
                break
            end

            local nodes = GetNodesFromRoom(room)

            if step > 0 then

                for _, node in ipairs(nodes) do
                    route[#route + 1] = {
                        Node = node,
                        RoomNumber = currentRoomNumber
                    }
                end

            else

                for i = #nodes, 1, -1 do
                    route[#route + 1] = {
                        Node = nodes[i],
                        RoomNumber = currentRoomNumber
                    }
                end

            end

            if currentRoomNumber == targetRoomNumber then
                break
            end

            currentRoomNumber += step
        end

        return route
    end

    --// DIRECT MOVEMENT //--

    local function MoveToward(targetPosition, deltaTime)
        if not model.Parent then
            return true
        end

        local pivot = model:GetPivot()
        local currentPosition = pivot.Position

        local difference =
            targetPosition - currentPosition

        local distance = difference.Magnitude

        if distance <= 0.15 then
            model:PivotTo(
                CFrame.new(targetPosition)
                * (pivot - pivot.Position)
            )

            return true
        end

        local direction = difference.Unit

        local movement =
            math.min(speed * deltaTime, distance)

        local newPosition =
            currentPosition + direction * movement

        local flatDirection =
            Vector3.new(
                direction.X,
                0,
                direction.Z
            )

        local newCFrame

        if flatDirection.Magnitude > 0.001 then
            newCFrame = CFrame.lookAt(
                newPosition,
                newPosition + flatDirection
            )
        else
            newCFrame =
                CFrame.new(newPosition)
                * (pivot - pivot.Position)
        end

        model:PivotTo(newCFrame)

        return false
    end

    --// HYBRID MOVEMENT LOOP //--

    task.spawn(function()

        -- Respect V2's configured movement delay.
        if movementDelay > 0 then
            task.wait(movementDelay)
        end

        if not model.Parent then
            return
        end

        local connection

        local route = {}
        local routeIndex = 1

        local lastPlayerRoomNumber = nil

        -- THIS IS THE IMPORTANT STATE.
        --
        -- It starts from the entity's physical room only once.
        -- After that, it is controlled by route nodes.

        local logicalEntityRoomNumber = nil

        --// INITIAL ROOM //--

        do
            local startingRoom = GetEntityRoom()

            if startingRoom then
                logicalEntityRoomNumber =
                    GetRoomNumber(startingRoom)
            end
        end

        if not logicalEntityRoomNumber then
            warn(
                "V3 HybridMovement: failed to determine initial entity room."
            )
            return
        end

        --// ROUTE RESET //--

        local function ResetRoute()
            table.clear(route)
            routeIndex = 1
        end

        --// ROUTE REBUILD //--

        local function RebuildRoute(playerRoomNumber)
            ResetRoute()

            if not logicalEntityRoomNumber
                or not playerRoomNumber
            then
                return
            end

            route = BuildRoute(
                logicalEntityRoomNumber,
                playerRoomNumber,
                model:GetPivot().Position
            )

            routeIndex = 1
        end

        --// HEARTBEAT //--

        connection = RunService.Heartbeat:Connect(function(deltaTime)

            if not model.Parent then
                connection:Disconnect()
                return
            end

            --// DESPAWN TIMER //--

            if despawnTime > 0
                and (os.clock() - spawnTime) >= despawnTime
            then

                if not model:GetAttribute("Despawning") then
                    model:SetAttribute("Despawning", true)

                    task.spawn(function()
                        pcall(function()
                            entity:RunCallback("OnDespawning")
                        end)
                    end)

                    pcall(function()
                        entity:Despawn()
                    end)
                end

                connection:Disconnect()
                return
            end

            --// PLAYER ROOT //--

            local playerRoot = GetPlayerRoot()

            if not playerRoot then
                return
            end

            --// PLAYER ROOM //--

            local playerRoom = GetPlayerRoom()

            if not playerRoom then
                return
            end

            local playerRoomNumber =
                GetRoomNumber(playerRoom)

            if not playerRoomNumber then
                return
            end

            --// SAME ROOM = CHASE //--

            if logicalEntityRoomNumber == playerRoomNumber then

                ResetRoute()

                lastPlayerRoomNumber =
                    playerRoomNumber

                MoveToward(
                    playerRoot.Position,
                    deltaTime
                )

                return
            end

            --// DIFFERENT ROOM = NODE MOVEMENT //--

            local playerRoomChanged =
                lastPlayerRoomNumber
                ~= playerRoomNumber

            if playerRoomChanged
                or routeIndex > #route
                or #route == 0
            then

                RebuildRoute(playerRoomNumber)

                lastPlayerRoomNumber =
                    playerRoomNumber
            end

            --// NO CURRENTLY LOADED ROUTE //--

            if #route == 0 then
                return
            end

            --// CURRENT NODE //--

            local routeData = route[routeIndex]

            if not routeData then
                ResetRoute()
                return
            end

            local node = routeData.Node
            local nodeRoomNumber = routeData.RoomNumber

            if not node then
                routeIndex += 1
                return
            end

            --// MOVE //--

            local targetPosition =
                GetNodePosition(node)

            local reached =
                MoveToward(
                    targetPosition,
                    deltaTime
                )

            --// NODE REACHED //--

            if reached then

                pcall(function()
                    entity:RunCallback(
                        "OnReachedNode",
                        node
                    )
                end)

                --// ADVANCE LOGICAL ROOM //--

                if nodeRoomNumber
                    and nodeRoomNumber ~= logicalEntityRoomNumber
                then

                    logicalEntityRoomNumber =
                        nodeRoomNumber

                end

                routeIndex += 1

                --// ROUTE COMPLETED //--

                if routeIndex > #route then

                    -- Rebuild using the logical room.
                    -- NEVER use GetEntityRoom() here.

                    RebuildRoute(
                        playerRoomNumber
                    )

                end
            end
        end)

        --// CLEANUP //--

        task.spawn(function()

            while model.Parent
                and entity:IsAlive()
            do
                task.wait(0.25)
            end

            if connection then
                connection:Disconnect()
            end

        end)
    end)

    return entity
end

--// SPAWN //--

function Brain.Spawn(config)
    if typeof(config) ~= "table" then
        error("V3 Brain: Spawn requires a config table.")
    end

    if CurrentEntity then
        pcall(function()
            CurrentEntity:Despawn()
        end)

        CurrentEntity = nil
        EntityActive = false
    end

    local model = PrepareModel(config)
    local assetList = ResolveConfigAssets(config)
    local v2Config = BuildV2Config(config, model)

    local ok, entity = pcall(function()
        return Original:Create(v2Config)
    end)

    if not ok or not entity then
        CleanupAssetFiles(assetList)
        error("V3 Brain: V2 Create failed:\n" .. tostring(entity))
    end

    local spawnState = {
        Time = os.clock()
    }

    SetupCallbacks(entity, config, assetList, spawnState)

    model = entity.Model or entity.model or model

    local runOk, runError = pcall(function()
        entity:Run()
    end)

    if not runOk then
        CleanupAssetFiles(assetList)
        error("V3 Brain: entity Run failed:\n" .. tostring(runError))
    end

    if config.Movement and config.Movement.FollowPlayer == true then
        StartHybridMovement(entity, config, spawnState.Time)
    end

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
end

getgenv().VynixuEntitySpawnerV3 = Brain

return Brain