--// V3 ENTITY BRAIN //--  
--// made by: 𝕝𝕦𝕟𝕒𝕣𝕓𝕣𝕖𝕓𝕖𝕒𝕦𝕥𝕪 𝕒𝕜𝕒 𝕖𝕝_𝕧𝕚𝕣𝕖𝕩𝕦𝕤!! //--  
  
if getgenv().VynixuEntitySpawnerV3 then
    return getgenv().VynixuEntitySpawnerV3
end
  
--// Services //--  
  
local Players = game:GetService("Players")  
local ContentProvider = game:GetService("ContentProvider")  
local Lighting = game:GetService("Lighting")  
local TweenService = game:GetService("TweenService")  
local RunService = game:GetService("RunService")  
  
local LocalPlayer = Players.LocalPlayer  
  
--// V2 SOURCE //--  
  
local V2_URL =  
    "https://gist.githubusercontent.com/reithirdtselmeg-lgtm/0f225198f5a454fbab1b16ffa052cd9d/raw/6a93182f55ea4b16ec7d3cf3e33b0911e80dee16/gistfile1.txt"  
  
--// external asset system //--  
  
local ASSET_FOLDER =  
    "V3EntityAssets"  
  
local ASSET_CLEANUP_DELAY = 10
  
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
        and (      
            value:match("^https://")      
            or value:match("^http://")      
        ) \~= nil  
  
end  
  
local function GetExtension(url, fallback)  
  
    if typeof(url) \~= "string" then      
        return fallback      
    end      
  
    local cleanUrl =      
        url:match("^[^?#]+")      
        or url      
  
    local extension =      
        cleanUrl:match("%.([%w]+)$")      
  
    if extension      
        and #extension <= 8 then      
  
        return extension:lower()      
  
    end      
  
    return fallback  
  
end  
  
local function SafeIsFile(path)  
  
    if not ExternalAssetFunctions.IsFile then      
        return false      
    end      
  
    local ok, result =      
        pcall(function()      
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
  
    local ok =      
        pcall(function()      
  
            if not isfolder      
                or not isfolder(ASSET_FOLDER) then      
  
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
  
    return ASSET_FOLDER      
        .. "/V3_"      
        .. randomPart      
        .. "."      
        .. extension  
  
end  
  
local function DownloadExternalAsset(  
    url,  
    fallbackExtension  
)  
  
    if not IsExternalUrl(url) then      
        return url, nil      
    end      
  
    if not ExternalAssetFunctions.HttpGet      
        or not ExternalAssetFunctions.WriteFile      
        or not ExternalAssetFunctions.GetCustomAsset then      
  
        warn(      
            "V3 Brain: external asset requires "      
            .. "HttpGet, writefile, and getcustomasset."      
        )      
  
        return nil, nil      
    end      
  
    if not EnsureAssetFolder() then      
  
        warn(      
            "V3 Brain: failed to prepare asset folder."      
        )      
  
        return nil, nil      
    end      
  
    local ok, data =      
        pcall(function()      
            return game:HttpGet(url)      
        end)      
  
    if not ok      
        or typeof(data) \~= "string"      
        or #data == 0 then      
  
        warn(      
            "V3 Brain: failed to download external asset:\n"      
            .. tostring(url)      
        )      
  
        return nil, nil      
    end      
  
    local extension =      
        GetExtension(      
            url,      
            fallbackExtension      
        )      
  
    local path =      
        GenerateAssetPath(      
            url,      
            extension      
        )      
  
    local writeOk =      
        pcall(function()      
            writefile(path, data)      
        end)      
  
    if not writeOk then      
  
        warn(      
            "V3 Brain: failed to write external asset:\n"      
            .. path      
        )      
  
        return nil, nil      
    end      
  
    local customOk, customAsset =      
        pcall(function()      
            return getcustomasset(path)      
        end)      
  
    if not customOk      
        or typeof(customAsset) \~= "string"      
        or customAsset == "" then      
  
        SafeDeleteFile(path)      
  
        warn(      
            "V3 Brain: getcustomasset failed:\n"      
            .. path      
        )      
  
        return nil, nil      
    end      
  
    return customAsset, path  
  
end  
  
local function ResolveAsset(  
    value,  
    fallbackExtension,  
    assetList  
)  
  
    if typeof(value) \~= "string"      
        or value == "" then      
  
        return value      
    end      
  
    if not IsExternalUrl(value) then      
        return value      
    end      
  
    local resolved, path =      
        DownloadExternalAsset(      
            value,      
            fallbackExtension      
        )      
  
    if path then      
  
        table.insert(      
            assetList,      
            path      
        )      
  
    end      
  
    return resolved  
  
end  
  
local function CleanupAssetFiles(assetList)  
  
    if typeof(assetList) \~= "table" then      
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
  
        return ResolveAsset(      
            value,      
            "png",      
            assetList      
        )      
  
    end      
  
    local function Sound(value)      
  
        return ResolveAsset(      
            value,      
            "ogg",      
            assetList      
        )      
  
    end      
  
    config.FaceId =      
        Image(config.FaceId)      
  
    if typeof(config.Auras) == "table" then  
        for i, auraData in ipairs(config.Auras) do  
            if i > 3 then break end  
            if typeof(auraData) == "table" and auraData.Id then  
                auraData.Id = Image(auraData.Id)  
            end  
        end  
    end  
  
    config.SpawnSound =      
        Sound(config.SpawnSound)      
  
    config.FarRushSound =      
        Sound(config.FarRushSound)      
  
    config.NearRushSound =      
        Sound(config.NearRushSound)      
  
    config.DespawnSound =      
        Sound(config.DespawnSound)      
  
    if config.Jumpscare then      
  
        config.Jumpscare.Image =      
            Image(config.Jumpscare.Image)      
  
        config.Jumpscare.Sound =      
            Sound(config.Jumpscare.Sound)      
  
    end      
  
    return assetList  
  
end  
  
--// V3 MOVEMENT PATCH //--  
  
local function PatchV2Source(source)  
  
    local movementStart =      
        source:find(      
            "local function EntityMoveTo",      
            1,      
            true      
        )      
  
    local earthquakeStart =      
        source:find(      
            "local function Earthquake",      
            1,      
            true      
        )      
  
    assert(      
        movementStart      
            and earthquakeStart      
            and earthquakeStart > movementStart,      
        "V3 Brain: failed to locate V2 EntityMoveTo."      
    )      
  
    local gap =      
        earthquakeStart - movementStart      
  
    assert(      
        gap > 20 and gap < 5000,      
        "V3 Brain: unexpected gap ("      
            .. gap      
            .. " chars) between EntityMoveTo and Earthquake — "      
            .. "V2 source structure may have changed, refusing to splice."      
    )      
  
    local newMovement = [[  
  
local function EntityMoveTo(model: Model, cframe: CFrame, speed: number)  
  
local reached = false      
local connection      
  
connection = RunService.Heartbeat:Connect(function(deltaTime)      
  
    if not model.Parent then      
        connection:Disconnect()      
        reached = true      
        return      
    end      
  
    if model:GetAttribute("Paused") then      
        return      
    end      
  
    local pivot = model:GetPivot()      
  
    local currentPosition = pivot.Position      
    local targetPosition = cframe.Position      
  
    local difference =      
        targetPosition - currentPosition      
  
    local distance =      
        difference.Magnitude      
  
    if distance <= 0.01 then      
  
        local rotationOnly =      
            pivot - pivot.Position      
  
        model:PivotTo(      
            CFrame.new(targetPosition)      
            * rotationOnly      
        )      
  
        connection:Disconnect()      
        reached = true      
  
        return      
    end      
  
    local direction =      
        difference / distance      
  
    local movement =      
        math.min(      
            speed * deltaTime,      
            distance      
        )      
  
    local newPosition =      
        currentPosition      
        + direction * movement      
  
    local flatDirection =      
        Vector3.new(      
            direction.X,      
            0,      
            direction.Z      
        )      
  
    local newCFrame      
  
    if flatDirection.Magnitude > 0.001 then      
  
        newCFrame =      
            CFrame.lookAt(      
                newPosition,      
                newPosition + flatDirection      
            )      
  
    else      
  
        local rotationOnly =      
            pivot - pivot.Position      
  
        newCFrame =      
            CFrame.new(newPosition)      
            * rotationOnly      
  
    end      
  
    model:PivotTo(newCFrame)      
  
end)      
  
repeat      
    RunService.Heartbeat:Wait()      
until reached  
  
end  
  
]]  
  
    source =      
        source:sub(      
            1,      
            movementStart - 1      
        )      
        .. newMovement      
        .. source:sub(      
            earthquakeStart      
        )      
  
    local patchedSource, matchCount =      
        source:gsub(      
            '"OnReachNode"',      
            '"OnReachedNode"'      
        )      
  
    if matchCount == 0 then      
  
        warn(      
            "V3 Brain: 'OnReachNode' -> "      
            .. "'OnReachedNode' patch matched 0 occurrences."      
        )      
  
    end      
  
    return patchedSource  
  
end  
  
--// Load patched V2 //--  
  
getgenv().VynixuEntitySpawnerV2 = nil  
  
local Original  
  
do  
  
    local ok, source =      
        pcall(function()      
            return game:HttpGet(V2_URL)      
        end)      
  
    if not ok      
        or typeof(source) \~= "string" then      
  
        error(      
            "V3 Brain: failed to download V2 source."      
        )      
  
    end      
  
    local patchOk, patchedSource =      
        pcall(function()      
            return PatchV2Source(source)      
        end)      
  
    if not patchOk then      
  
        error(      
            "V3 Brain: failed to patch V2 movement:\n"      
            .. tostring(patchedSource)      
        )      
  
    end      
  
    local loadOk, result =      
        pcall(function()      
            return loadstring(patchedSource)()      
        end)      
  
    if not loadOk      
        or typeof(result) \~= "table" then      
  
        error(      
            "V3 Brain: failed to load patched V2:\n"      
            .. tostring(result)      
        )      
  
    end      
  
    Original = result      
  
    getgenv().VynixuEntitySpawnerV2 =      
        Original  
  
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
  
    if typeof(value) \~= "string" then      
        return Color3.new(1, 1, 1)      
    end      
  
    if AuraColors[value] then      
        return AuraColors[value]      
    end      
  
    local left, right =      
        value:match(      
            "^%s*(.-)%s*%+%s*(.-)%s*$"      
        )      
  
    if left and right then      
  
        if string.find(right, "%+") then      
            return Color3.new(1, 1, 1)      
        end      
  
        local color1 =      
            AuraColors[left]      
  
        local color2 =      
            AuraColors[right]      
  
        if color1 and color2 then      
            return MixColors(      
                color1,      
                color2      
            )      
        end      
  
    end      
  
    return Color3.new(1, 1, 1)  
  
end  
  
--// state //--  
  
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
  
    return model:FindFirstChild(      
        "FacePart",      
        true      
    )      
    or model:FindFirstChild(      
        "Head",      
        true      
    )      
    or model.PrimaryPart  
  
end  
  
--// make entity //--  
  
local function PrepareModel(config)  
  
    local model =      
        Instance.new("Model")      
  
    model.Name =      
        config.EntityName      
        or "CustomEntity"      
  
    local root =      
        Instance.new("Part")      
  
    root.Name = "Root"      
    root.Size =      
        Vector3.new(2, 2, 2)      
  
    root.Transparency = 1      
    root.Anchored = true      
    root.CanCollide = false      
    root.CanTouch = false      
    root.CanQuery = false      
    root.CastShadow = false      
  
    root.Parent = model      
  
    model.PrimaryPart = root      
  
    local face =      
        Instance.new("Part")      
  
    face.Name = "FacePart"      
  
    face.Size =      
        Vector3.new(4, 4, 0.2)      
  
    face.Transparency = 1      
    face.Anchored = false      
    face.CanCollide = false      
    face.CanTouch = false      
    face.CanQuery = false      
    face.CastShadow = false      
  
    face.CFrame =      
        root.CFrame      
        * CFrame.new(      
            0,      
            0,      
            -1.2      
        )      
  
    face.Parent = model      
  
    local weld =      
        Instance.new(      
            "WeldConstraint"      
        )      
  
    weld.Part0 = root      
    weld.Part1 = face      
    weld.Parent = face      
  
    return model  
  
end  
  
--// face //--  
  
local function SetupFace(model, config)  
  
    local facePart =      
        FindFacePart(model)      
  
    if not facePart then      
        return      
    end      
  
    local faceId =      
        config.FaceId      
  
    if typeof(faceId) \~= "string"      
        or faceId == "" then      
        return      
    end      
  
    local attachment =      
        facePart:FindFirstChild(      
            "FaceAttachment"      
        )      
  
    if not attachment then      
  
        attachment =      
            Instance.new(      
                "Attachment"      
            )      
  
        attachment.Name =      
            "FaceAttachment"      
  
        attachment.Parent =      
            facePart      
  
    end      
  
    local emitter =      
        attachment:FindFirstChild(      
            "FaceParticle"      
        )      
  
    if not emitter then      
  
        emitter =      
            Instance.new(      
                "ParticleEmitter"      
            )      
  
        emitter.Name =      
            "FaceParticle"      
  
        emitter.Parent =      
            attachment      
  
    end      
  
    emitter.Texture =      
        faceId      
  
    for property, value in      
        pairs(      
            config.FaceParticle or {}      
        ) do      
  
        pcall(function()      
            emitter[property] = value      
        end)      
  
    end  
  
end  
  
--// multi-aura //--  
  
local function SetupAura(model, config)  
  
    local root =  
        model.PrimaryPart  
  
    if not root  
        or typeof(config.Auras) \~= "table"  
        or #config.Auras == 0 then  
        return  
    end  
  
    --// AURA #1 MUST DEFINE THE MASTER COLOR //--  
  
    local firstAura =  
        config.Auras[1]  
  
    if typeof(firstAura) \~= "table"  
        or typeof(firstAura.Id) \~= "string"  
        or firstAura.Id == "" then  
  
        warn(  
            "V3 Brain: Aura #1 must have a valid Id."  
        )  
  
        return  
    end  
  
    if firstAura.Color == nil then  
  
        warn(  
            "V3 Brain: Aura #1 MUST define the master Color."  
        )  
  
        return  
    end  
  
    local masterColor =  
        GetColor(firstAura.Color)  
  
    local masterColorSequence =  
        ColorSequence.new(masterColor)  
  
    --// CREATE 1-3 AURAS //--  
  
    for index = 1, math.min(#config.Auras, 3) do  
  
        local auraData =  
            config.Auras[index]  
  
        if typeof(auraData) == "table"  
            and typeof(auraData.Id) == "string"  
            and auraData.Id \~= "" then  
  
            local attachmentName =  
                "AuraAttachment" .. index  
  
            local particleName =  
                "AuraParticle" .. index  
  
            local attachment =  
                root:FindFirstChild(  
                    attachmentName  
                )  
  
            if not attachment then  
  
                attachment =  
                    Instance.new("Attachment")  
  
                attachment.Name =  
                    attachmentName  
  
                attachment.Parent =  
                    root  
  
            end  
  
            local emitter =  
                attachment:FindFirstChild(  
                    particleName  
                )  
  
            if not emitter then  
  
                emitter =  
                    Instance.new("ParticleEmitter")  
  
                emitter.Name =  
                    particleName  
  
                emitter.Parent =  
                    attachment  
  
            end  
  
            emitter.Texture =  
                auraData.Id  
  
            --// ALL AURAS USE AURA #1 COLOR //--  
  
            emitter.Color =  
                masterColorSequence  
  
            --// EACH AURA HAS ITS OWN SETTINGS //--  
  
            for property, value in  
                pairs(auraData.Settings or {}) do  
  
                pcall(function()  
  
                    emitter[property] =  
                        value  
  
                end)  
  
            end  
  
        end  
  
    end  
  
end  
  
--// entity lamp //--  
  
local function SetupLight(  
    model,  
    data,  
    name  
)  
  
    local root =      
        model.PrimaryPart      
  
    if not root then      
        return      
    end      
  
    local oldLight =      
        root:FindFirstChild(name)      
  
    if oldLight then      
        SafeDestroy(oldLight)      
    end      
  
    if not data      
        or not data.Enabled then      
        return      
    end      
  
    local light =      
        Instance.new("PointLight")      
  
    light.Name = name      
    light.Color =      
        GetColor(data.Color)      
  
    light.Range =      
        data.Range or 30      
  
    light.Brightness =      
        data.Brightness or 2      
  
    light.Enabled = true      
    light.Parent = root      
  
    return light  
  
end  
  
--// environment //--  
  
local function SetupEnvironment(config)  
  
    if EnvironmentEffect then      
  
        SafeDestroy(      
            EnvironmentEffect      
        )      
  
        EnvironmentEffect = nil      
  
    end      
  
    local data =      
        config.EnvironmentColor      
  
    if not data      
        or not data.Enabled then      
        return      
    end      
  
    local effect =      
        Instance.new(      
            "ColorCorrectionEffect"      
        )      
  
    effect.Name =      
        "V3EntityEnvironmentColor"      
  
    local targetColor =      
        GetColor(data.Color)      
  
    local strength =      
        math.clamp(      
            tonumber(data.Strength)      
                or 45,      
            0,      
            100      
        ) / 100      
  
    local targetTint =      
        Color3.new(      
            1      
                + (targetColor.R - 1)      
                * strength,      
  
            1      
                + (targetColor.G - 1)      
                * strength,      
  
            1      
                + (targetColor.B - 1)      
                * strength      
        )      
  
    effect.TintColor =      
        Color3.new(1, 1, 1)      
  
    effect.Brightness = 0      
    effect.Contrast = 0      
    effect.Saturation = 0      
  
    effect.Parent = Lighting      
  
    EnvironmentEffect =      
        effect      
  
    local fadeIn =      
        math.max(      
            tonumber(data.FadeIn)      
                or 0.5,      
            0      
        )      
  
    local tween =      
        TweenService:Create(      
            effect,      
            TweenInfo.new(      
                fadeIn,      
                Enum.EasingStyle.Quad,      
                Enum.EasingDirection.Out      
            ),      
            {      
                TintColor = targetTint,      
                Brightness =      
                    strength * 0.15,      
                Contrast =      
                    strength * 0.25,      
                Saturation =      
                    strength * 0.1      
            }      
        )      
  
    tween:Play()  
  
end  
  
local function RemoveEnvironment(config)  
  
    local effect =      
        EnvironmentEffect      
  
    if not effect then      
        return      
    end      
  
    EnvironmentEffect = nil      
  
    local data =      
        config.EnvironmentColor      
        or {}      
  
    local fadeOut =      
        math.max(      
            tonumber(data.FadeOut)      
                or 0.5,      
            0      
        )      
  
    local tween =      
        TweenService:Create(      
            effect,      
            TweenInfo.new(      
                fadeOut,      
                Enum.EasingStyle.Quad,      
                Enum.EasingDirection.Out      
            ),      
            {      
                TintColor =      
                    Color3.new(      
                        1,      
                        1,      
                        1      
                    ),      
  
                Brightness = 0,      
                Contrast = 0,      
                Saturation = 0      
            }      
        )      
  
    tween:Play()      
  
    task.delay(      
        fadeOut,      
        function()      
            SafeDestroy(effect)      
        end      
    )  
  
end  
  
--// sounds //--  
  
local function CreateSound(  
    parent,  
    soundId,  
    volume,  
    playbackSpeed,  
    name,  
    looped  
)  
  
    if not parent      
        or typeof(soundId) \~= "string"      
        or soundId == "" then      
  
        return nil      
    end      
  
    local sound =      
        Instance.new("Sound")      
  
    sound.Name =      
        name or "V3Sound"      
  
    sound.SoundId =      
        soundId      
  
    sound.Volume =      
        volume or 1      
  
    sound.Looped =      
        looped == true      
  
    sound.PlaybackSpeed =      
        playbackSpeed or 1      
  
    sound.Parent =      
        parent      
  
    return sound  
  
end  
  
--// spawn sound //--  
  
local function PlaySpawnSound(  
    config  
)  
  
    local playerGui =      
        LocalPlayer:FindFirstChildOfClass(      
            "PlayerGui"      
        )      
  
    if not playerGui then      
        return      
    end      
  
    local sound =      
        CreateSound(      
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
  
    task.delay(      
        config.SpawnSoundTimeout      
            or 5,      
  
        function()      
            SafeDestroy(sound)      
        end      
    )  
  
end  
  
--// rush sounds //--  
  
local function PlayRushSound(  
    model,  
    soundId,  
    volume,  
    playbackSpeed,  
    name  
)  
  
    if not model then      
        return      
    end      
  
    local facePart = model:FindFirstChild("FacePart", true)      
  
    if not facePart then      
        return      
    end      
  
    local sound =      
        CreateSound(      
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
    sound.RollOffMaxDistance = 165      
  
    ActiveSounds[sound] =      
        true      
  
    sound:Play()  
  
end  
  
local function FadeOutActiveSounds(  
    duration  
)  
  
    duration =      
        math.max(      
            tonumber(duration)      
                or 3,      
            0      
        )      
  
    local soundsToFade = {}      
  
    for sound, _ in      
        pairs(ActiveSounds) do      
  
        table.insert(      
            soundsToFade,      
            sound      
        )      
  
    end      
  
    table.clear(      
        ActiveSounds      
    )      
  
    for _, sound in      
        ipairs(soundsToFade) do      
  
        if sound      
            and sound.Parent then      
  
            local tween =      
                TweenService:Create(      
                    sound,      
  
                    TweenInfo.new(      
                        duration,      
                        Enum.EasingStyle.Linear,      
                        Enum.EasingDirection.Out      
                    ),      
  
                    {      
                        Volume = 0      
                    }      
                )      
  
            tween:Play()      
  
            task.delay(      
                duration,      
                function()      
  
                    SafeDestroy(      
                        sound      
                    )      
  
                end      
            )      
  
        end      
  
    end  
  
end  
  
--// despawn sound //--  
  
local function PlayDespawnSound(config)  
  
    local playerGui =      
        LocalPlayer:FindFirstChildOfClass(      
            "PlayerGui"      
        )      
  
    if not playerGui then      
        return      
    end      
  
    local sound =      
        CreateSound(      
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
  
    task.delay(      
        config.DespawnSoundTimeout      
            or 5,      
  
        function()      
            SafeDestroy(sound)      
        end      
    )  
  
end  
  
--// preload //--  
  
local function Preload(config)  
  
    local assets = {}      
  
    local function AddAsset(      
        id,      
        className      
    )      
  
        if typeof(id) \~= "string"      
            or id == "" then      
            return      
        end      
  
        local asset =      
            Instance.new(className)      
  
        asset.Name =      
            "V3Preload"      
  
        if asset:IsA(      
            "ImageLabel"      
        ) then      
  
            asset.Image = id      
  
        elseif asset:IsA(      
            "Sound"      
        ) then      
  
            asset.SoundId = id      
  
        end      
  
        asset.Parent =      
            game:GetService(      
                "CoreGui"      
            )      
  
        table.insert(      
            assets,      
            asset      
        )      
  
    end      
  
    AddAsset(      
        config.FaceId,      
        "ImageLabel"      
    )      
  
    if typeof(config.Auras) == "table" then  
        for i, auraData in ipairs(config.Auras) do  
            if i > 3 then break end  
            if typeof(auraData) == "table" then  
                AddAsset(      
                    auraData.Id,      
                    "ImageLabel"      
                )  
            end  
        end  
    end  
  
    AddAsset(      
        config.SpawnSound,      
        "Sound"      
    )      
  
    AddAsset(      
        config.FarRushSound,      
        "Sound"      
    )      
  
    AddAsset(      
        config.NearRushSound,      
        "Sound"      
    )      
  
    AddAsset(      
        config.DespawnSound,      
        "Sound"      
    )      
  
    if config.Jumpscare then      
  
        AddAsset(      
            config.Jumpscare.Image,      
            "ImageLabel"      
        )      
  
        AddAsset(      
            config.Jumpscare.Sound,      
            "Sound"      
        )      
  
    end      
  
    if #assets > 0 then      
  
        pcall(function()      
  
            ContentProvider:PreloadAsync(      
                assets      
            )      
  
        end)      
  
    end      
  
    for _, asset in      
        ipairs(assets) do      
  
        SafeDestroy(asset)      
  
    end  
  
end  
  
--// jumpscare //--  
  
local function RunJumpscare(config)  
  
    local data =      
        config.Jumpscare      
  
    if not data      
        or not data.Enabled then      
        return      
    end      
  
    local playerGui =      
        LocalPlayer:FindFirstChildOfClass(      
            "PlayerGui"      
        )      
  
    if not playerGui then      
        return      
    end      
  
    local gui =      
        Instance.new("ScreenGui")      
  
    gui.Name =      
        "V3EntityJumpscare"      
  
    gui.IgnoreGuiInset = true      
    gui.ResetOnSpawn = false      
    gui.DisplayOrder =      
        999999      
  
    gui.Parent =      
        playerGui      
  
    --// FLASH //--      
  
    local flash =      
        Instance.new("Frame")      
  
    flash.Name = "Flash"      
  
    flash.Size =      
        UDim2.fromScale(      
            4,      
            4      
        )      
  
    flash.BackgroundColor3 =      
        GetColor(      
            data.FlashColor      
        )      
  
    flash.BackgroundTransparency =      
        0      
  
    flash.BorderSizePixel = 0      
  
    flash.Parent = gui      
  
    --// FACE //--      
  
    local image =      
        Instance.new(      
            "ImageLabel"      
        )      
  
    image.Name = "Face"      
  
    image.AnchorPoint =      
        Vector2.new(      
            0.5,      
            0.5      
        )      
  
    image.Position =      
        UDim2.fromScale(      
            0.5,      
            0.5      
        )      
  
    image.BackgroundTransparency =      
        1      
  
    image.ScaleType =      
        Enum.ScaleType.Fit      
  
    local startSize =      
        data.StartSize      
        or 0.2      
  
    image.Size =      
        UDim2.fromScale(      
            startSize,      
            startSize      
        )      
  
    image.Image =      
        data.Image      
        or config.FaceId      
  
    image.Parent = gui      
  
    --// SOUND //--      
  
    local sound      
  
    if typeof(data.Sound)      
        == "string"      
        and data.Sound \~= "" then      
  
        sound =      
            Instance.new("Sound")      
  
        sound.Name =      
            "JumpscareSound"      
  
        sound.SoundId =      
            data.Sound      
  
        sound.Volume =      
            data.Volume      
            or 1      
  
        sound.Looped = false      
        sound.Parent = gui      
  
        if data.PitchShiftEnabled then      
  
            local pitch =      
                Instance.new(      
                    "PitchShiftSoundEffect"      
                )      
  
            pitch.Octave = 1      
            pitch.Parent = sound      
  
        end      
  
        sound:Play()      
  
    end      
  
    local duration =      
        math.max(      
            data.Duration      
                or 0.6,      
            0.05      
        )      
  
    --// FLASH //--      
  
    if data.FlashEnabled then      
  
        local flashColor =      
            GetColor(      
                data.FlashColor      
            )      
  
        local black =      
            Color3.new(      
                0,      
                0,      
                0      
            )      
  
        flash.BackgroundColor3 =      
            flashColor      
  
        flash.BackgroundTransparency =      
            0      
  
        task.spawn(function()      
  
            local flashSpeed =      
                math.max(      
                    data.FlashSpeed      
                        or 0.1,      
                    0.01      
                )      
  
            local startTime =      
                os.clock()      
  
            local useColor = false      
  
            while gui.Parent do      
  
                local elapsed =      
                    os.clock()      
                    - startTime      
  
                if elapsed >= duration then      
                    break      
                end      
  
                useColor =      
                    not useColor      
  
                local targetColor      
  
                if useColor then      
                    targetColor =      
                        flashColor      
                else      
                    targetColor =      
                        black      
                end      
  
                flash.BackgroundColor3 =      
                    targetColor      
  
                flash.BackgroundTransparency =      
                    0      
  
                task.wait(      
                    flashSpeed      
                )      
  
            end      
  
        end)      
  
    else      
  
        flash.BackgroundTransparency =      
            1      
  
    end      
  
    --// FACE GROW //--      
  
    local wiggleAngle =      
        data.WiggleAngle      
        or 15      
  
    TweenService:Create(      
        image,      
  
        TweenInfo.new(      
            duration,      
            Enum.EasingStyle.Exponential,      
            Enum.EasingDirection.Out      
        ),      
  
        {      
            Size =      
                UDim2.fromScale(      
                    1,      
                    1      
                )      
        }      
  
    ):Play()      
  
    --// WIGGLE //--      
  
    task.spawn(function()      
  
        local startTime =      
            os.clock()      
  
        local direction = 1      
  
        while gui.Parent do      
  
            local elapsed =      
                os.clock()      
                - startTime      
  
            local alpha =      
                math.clamp(      
                    elapsed / duration,      
                    0,      
                    1      
                )      
  
            if alpha >= 1 then      
                break      
            end      
  
            local fade =      
                1 - alpha      
  
            local angle =      
                wiggleAngle      
                * fade      
                * direction      
  
            image.Rotation =      
                angle      
  
            local waitTime =      
                0.025      
                + alpha * 0.08      
  
            task.wait(      
                waitTime      
            )      
  
            direction =      
                -direction      
  
        end      
  
        if image.Parent then      
            image.Rotation = 0      
        end      
  
    end)      
  
    task.wait(duration)      
  
    SafeDestroy(gui)  
  
end  
  
--// V3 → V2 config //--  
  
local function BuildV2Config(  
    config,  
    model  
)  
  
    return {      
  
        Entity = {      
  
            Name =      
                config.EntityName      
                or "CustomEntity",      
  
            Asset = model,      
  
            HeightOffset =      
                config.HeightOffset      
                or 0      
        },      
  
        Movement = {      
  
            Speed =      
                config.Movement.Speed,      
  
            Delay =      
                config.Movement.Delay,      
  
            Reversed =      
                config.Movement.Reversed      
        },      
  
        Damage = {      
  
            Enabled =      
                config.Damage.Enabled,      
  
            IgnoreHiding =      
                config.Damage.IgnoreHiding,      
  
            Range =      
                config.Damage.Range,      
  
            Amount =      
                config.Damage.Amount      
        },      
  
        Lights = {      
  
            Flicker = {      
  
                Enabled =      
                    config.Lights.Flicker.Enabled,      
  
                Duration =      
                    config.Lights.Flicker.Duration      
            },      
  
            Shatter =      
                config.Lights.Shatter,      
  
            Repair =      
                config.Lights.Repair      
        },      
  
        Earthquake = {      
  
            Enabled =      
                config.Earthquake.Enabled      
        },      
  
        CameraShake = {      
  
            Enabled =      
                config.CameraShake.Enabled,      
  
            Range =      
                config.CameraShake.Range,      
  
            Values =      
                config.CameraShake.Values      
        },      
  
        Crucifixion = {      
  
            Type =      
                config.Crucifixion.Type,      
  
            Enabled =      
                config.Crucifixion.Enabled,      
  
            Range =      
                config.Crucifixion.Range,      
  
            Resist =      
                config.Crucifixion.Resist,      
  
            Break =      
                config.Crucifixion.Break      
        },      
  
        Rebounding = {      
  
            Enabled =      
                config.Rebounding.Enabled,      
  
            Type =      
                config.Rebounding.Type,      
  
            Min =      
                config.Rebounding.Min,      
  
            Max =      
                config.Rebounding.Max,      
  
            Delay =      
                config.Rebounding.Delay      
        },      
  
        Death = {      
  
            Type =      
                config.Death.Type,      
  
            Hints =      
                config.Death.Hints,      
  
            Cause =      
                config.Death.Cause      
        }      
  
    }  
  
end  
  
--// callbacks //--  
  
local function SetupCallbacks(  
    entity,  
    config,  
    assetList  
)  
  
    entity:SetCallback(      
        "OnSpawned",      
        function()      
  
            EntityActive = true      
            CurrentEntity = entity      
  
            local model =      
                entity.Model      
  
            if not model then      
                return      
            end      
  
            SetupFace(      
                model,      
                config      
            )      
  
            SetupAura(      
                model,      
                config      
            )      
  
            SetupLight(      
                model,      
                config.EntityLight,      
                "EntityLight"      
            )      
  
            SetupLight(      
                model,      
                config.EntityLamp2,      
                "EntityLamp2"      
            )      
  
            SetupEnvironment(      
                config      
            )      
  
            PlaySpawnSound(      
                config      
            )      
  
        end      
    )      
  
    entity:SetCallback(      
        "OnStartMoving",      
        function()      
  
            local model =      
                entity.Model      
  
            if not model then      
                return      
            end      
  
            PlayRushSound(      
                model,      
                config.FarRushSound,      
                config.FarVolume,      
                config.FarPlaybackSpeed,      
                "FarRush"      
            )      
  
        end      
    )      
  
    entity:SetCallback(      
        "OnReachedNode",      
        function(...)      
  
            if not EntityActive then      
                return      
            end      
  
        end      
    )      
  
    entity:SetCallback(      
        "OnEnterRoom",      
        function(      
            room,      
            firstTime      
        )      
  
            if not EntityActive then      
                return      
            end      
  
            local model =      
                entity.Model      
  
            if not model then      
                return      
            end      
  
            if firstTime then      
  
                PlayRushSound(      
                    model,      
                    config.NearRushSound,      
                    config.NearVolume,      
                    config.NearPlaybackSpeed,      
                    "NearRush"      
                )      
  
            end      
  
        end      
    )      
  
    entity:SetCallback(      
        "OnLookAt",      
        function(...)      
  
            if not EntityActive then      
                return      
            end      
  
        end      
    )      
  
    entity:SetCallback(      
        "OnRebounding",      
        function(...)      
  
            if not EntityActive then      
                return      
            end      
  
        end      
    )      
  
    entity:SetCallback(      
        "OnDespawning",      
        function()      
  
            FadeOutActiveSounds(      
                0.3      
            )      
  
            RemoveEnvironment(      
                config      
            )      
  
        end      
  
    )      
  
    entity:SetCallback(      
        "OnDespawned",      
        function()      
  
            EntityActive = false      
  
            if CurrentEntity == entity then      
                CurrentEntity = nil      
            end      
  
            RemoveEnvironment(      
                config      
            )      
  
            PlayDespawnSound(      
                config      
            )      
  
            local ownedAssets =      
                assetList      
  
            task.delay(      
                ASSET_CLEANUP_DELAY,      
                function()      
  
                    CleanupAssetFiles(      
                        ownedAssets      
                    )      
  
                end      
            )      
  
        end      
    )      
  
    entity:SetCallback(      
        "OnDamagePlayer",      
        function(newHealth)      
  
            if not EntityActive then      
                return      
            end      
  
            if config.Jumpscare      
                and config.Jumpscare.Enabled then      
  
                task.spawn(function()      
  
                    RunJumpscare(      
                        config      
                    )      
  
                end)      
  
            end      
  
        end      
    )  
  
end  
  
--// V3 SPAWN //--  
  
local Brain = {}  
  
function Brain.Spawn(config)  
  
    assert(      
        type(config) == "table",      
        "V3 Brain: Config must be a table."      
    )      
  
    if EntityActive      
        and CurrentEntity then      
  
        pcall(function()      
  
            if CurrentEntity:IsAlive() then      
                CurrentEntity:Despawn()      
            else      
                StopAllActiveSounds()      
            end      
  
        end)      
  
    else      
  
        StopAllActiveSounds()      
  
    end      
  
    EntityActive = false      
    CurrentEntity = nil      
  
    local assetList =      
        ResolveConfigAssets(      
            config      
        )      
  
    task.spawn(function()      
  
        Preload(      
            config      
        )      
  
    end)      
  
    local model =      
        PrepareModel(      
            config      
        )      
  
    local v2Config =      
        BuildV2Config(      
            config,      
            model      
        )      
  
    local ok, entity =      
        pcall(function()      
  
            return Original:Create(      
                v2Config      
            )      
  
        end)      
  
    if not ok or not entity then      
  
        SafeDestroy(model)      
  
        CleanupAssetFiles(      
            assetList      
        )      
  
        error(      
            "V3 Brain: V2 Create failed: "      
            .. tostring(entity)      
        )      
  
    end      
  
    SetupCallbacks(      
        entity,      
        config,      
        assetList      
    )      
  
    local runOk, runError =      
        pcall(function()      
  
            entity:Run(false)      
  
        end)      
  
    if not runOk then      
  
        pcall(function()      
            entity:Despawn()      
        end)      
  
        SafeDestroy(model)      
  
        task.delay(      
            ASSET_CLEANUP_DELAY,      
            function()      
  
                CleanupAssetFiles(      
                    assetList      
                )      
  
            end      
        )      
  
        error(      
            "V3 Brain: V2 Run failed: "      
            .. tostring(runError)      
        )      
  
    end

-- ============================================================
-- FOLLOW PLAYER OVERRIDE
-- FULL V3 MOVEMENT CONTROL
--
-- V2 node movement is completely overridden.
--
-- BEHAVIOR:
--   1. V3 follows the DOORS node system itself.
--   2. Same room as player -> direct wall chase.
--   3. Player changes rooms -> direct chase stops.
--   4. V3 resumes node movement toward the player's room.
--   5. Enter player's new room -> direct wall chase again.
-- ============================================================

if config.Movement and config.Movement.FollowPlayer == true then
    task.spawn(function()

        local model = entity.Model
        if not model then
            return
        end

        local speed =
            tonumber(entity.Config.Movement.Speed)
            or tonumber(config.Movement.Speed)
            or 50

        local heightOffset =
            tonumber(config.HeightOffset)
            or 0

        local despawnTime =
            tonumber(config.Movement.FollowPlayerDespawnTime)
            or 45

        local startTime = os.clock()

        local CurrentRooms =
            workspace:WaitForChild("CurrentRooms")

        local directChasing = false
        local currentTargetRoom = nil
        local nodeIndex = 1
        local nodes = {}

        local connection

        -- ========================================================
        -- ROOM DETECTION
        -- ========================================================

        local function GetRoomAtPoint(position)

            local whitelist = {}

            for _, room in ipairs(CurrentRooms:GetChildren()) do

                local roomPart =
                    room:FindFirstChild(room.Name)

                if roomPart
                    and roomPart:IsA("BasePart")
                then
                    table.insert(
                        whitelist,
                        roomPart
                    )
                end
            end

            if #whitelist == 0 then
                return nil
            end

            local params =
                RaycastParams.new()

            params.FilterType =
                Enum.RaycastFilterType.Include

            params.FilterDescendantsInstances =
                whitelist

            params.CollisionGroup =
                "BaseCheck"

            local result =
                workspace:Raycast(
                    position,
                    Vector3.new(0, -100, 0),
                    params
                )

            if not result then
                return nil
            end

            for _, room in ipairs(CurrentRooms:GetChildren()) do

                if result.Instance.Parent == room then
                    return room
                end

            end

            return nil

        end

        local function GetPlayerRoom()

            local roomNumber =
                LocalPlayer:GetAttribute(
                    "CurrentRoom"
                )

            if roomNumber ~= nil then

                local room =
                    CurrentRooms:FindFirstChild(
                        tostring(roomNumber)
                    )

                if room then
                    return room
                end

            end

            local char =
                LocalPlayer.Character

            local root =
                char
                and (
                    char.PrimaryPart
                    or char:FindFirstChild(
                        "HumanoidRootPart"
                    )
                )

            if root then
                return GetRoomAtPoint(
                    root.Position
                )
            end

            return nil

        end

        -- ========================================================
        -- V3 NODE BUILDER
        --
        -- Same basic node structure used by V2:
        --
        -- RoomEntrance
        -- PathfindNodes
        -- RoomExit
        -- ========================================================

        local function GetNodesFromRoom(room)

            local roomNodes = {}

            if not room then
                return roomNodes
            end

            local entrance =
                room:FindFirstChild(
                    "RoomEntrance"
                )

            if entrance then

                local clone =
                    entrance:Clone()

                clone.Name = "0"

                clone.CFrame =
                    clone.CFrame
                    - Vector3.new(0, 3, 0)

                table.insert(
                    roomNodes,
                    clone
                )

            end

            local pathfindNodes =
                room:FindFirstChild(
                    "PathfindNodes"
                )

            if pathfindNodes then

                for _, node in ipairs(
                    pathfindNodes:GetChildren()
                ) do

                    table.insert(
                        roomNodes,
                        node
                    )

                end

            end

            local exit =
                room:FindFirstChild(
                    "RoomExit"
                )

            if exit then

                local clone =
                    exit:Clone()

                clone.Name =
                    tostring(#roomNodes)

                clone.CFrame =
                    clone.CFrame
                    - Vector3.new(0, 3, 0)

                table.insert(
                    roomNodes,
                    clone
                )

            end

            table.sort(
                roomNodes,
                function(a, b)

                    return tonumber(a.Name)
                        < tonumber(b.Name)

                end
            )

            return roomNodes

        end

        -- ========================================================
        -- BUILD ROUTE
        --
        -- Build nodes from entity's current room toward
        -- the player's current room.
        -- ========================================================

        local function BuildRoute()

            table.clear(nodes)

            nodeIndex = 1

            local entityRoom =
                GetRoomAtPoint(
                    model:GetPivot().Position
                )

            local playerRoom =
                GetPlayerRoom()

            if not entityRoom
                or not playerRoom
            then
                return
            end

            local entityNumber =
                tonumber(entityRoom.Name)

            local playerNumber =
                tonumber(playerRoom.Name)

            if not entityNumber
                or not playerNumber
            then
                return
            end

            currentTargetRoom =
                playerRoom

            -- ----------------------------------------------------
            -- Same room
            -- Direct chase will handle this.
            -- ----------------------------------------------------

            if entityNumber == playerNumber then
                return
            end

            -- ----------------------------------------------------
            -- Determine direction.
            -- ----------------------------------------------------

            local step

            if playerNumber > entityNumber then
                step = 1
            else
                step = -1
            end

            local roomNumber =
                entityNumber

            while roomNumber ~= playerNumber do

                local room =
                    CurrentRooms:FindFirstChild(
                        tostring(roomNumber)
                    )

                if room then

                    local roomNodes =
                        GetNodesFromRoom(room)

                    if step == -1 then

                        for i =
                            #roomNodes,
                            1,
                            -1
                        do

                            table.insert(
                                nodes,
                                roomNodes[i]
                            )

                        end

                    else

                        for _, node in ipairs(
                            roomNodes
                        ) do

                            table.insert(
                                nodes,
                                node
                            )

                        end

                    end

                end

                roomNumber =
                    roomNumber + step

            end

            -- ----------------------------------------------------
            -- Add the player's room nodes.
            -- ----------------------------------------------------

            local finalRoom =
                CurrentRooms:FindFirstChild(
                    tostring(playerNumber)
                )

            if finalRoom then

                local finalNodes =
                    GetNodesFromRoom(
                        finalRoom
                    )

                if step == -1 then

                    for i =
                        #finalNodes,
                        1,
                        -1
                    do

                        table.insert(
                            nodes,
                            finalNodes[i]
                        )

                    end

                else

                    for _, node in ipairs(
                        finalNodes
                    ) do

                        table.insert(
                            nodes,
                            node
                        )

                    end

                end

            end

        end

        -- ========================================================
        -- DIRECT PLAYER CHASE
        -- ========================================================

        local function ChasePlayer(dt)

            local char =
                LocalPlayer.Character

            local root =
                char
                and (
                    char.PrimaryPart
                    or char:FindFirstChild(
                        "HumanoidRootPart"
                    )
                )

            if not root then
                return
            end

            local targetPosition =
                root.Position
                + Vector3.new(
                    0,
                    heightOffset,
                    0
                )

            local pivot =
                model:GetPivot()

            local difference =
                targetPosition
                - pivot.Position

            local distance =
                difference.Magnitude

            if distance <= 0.15 then
                return
            end

            local direction =
                difference.Unit

            local movement =
                math.min(
                    speed * dt,
                    distance
                )

            local newPosition =
                pivot.Position
                + direction * movement

            local flatDirection =
                Vector3.new(
                    direction.X,
                    0,
                    direction.Z
                )

            if flatDirection.Magnitude > 0.001 then

                model:PivotTo(
                    CFrame.lookAt(
                        newPosition,
                        newPosition
                            + flatDirection
                    )
                )

            else

                local rotationOnly =
                    pivot
                    - pivot.Position

                model:PivotTo(
                    CFrame.new(newPosition)
                    * rotationOnly
                )

            end

        end

        -- ========================================================
        -- NODE MOVEMENT
        -- ========================================================

        local function MoveToNode(node, dt)

            if not node
                or not node.Parent
            then
                return true
            end

            local targetPosition =
                node.Position

            local pivot =
                model:GetPivot()

            local difference =
                targetPosition
                - pivot.Position

            local distance =
                difference.Magnitude

            if distance <= 1.5 then
                return true
            end

            local direction =
                difference.Unit

            local movement =
                math.min(
                    speed * dt,
                    distance
                )

            local newPosition =
                pivot.Position
                + direction * movement

            local flatDirection =
                Vector3.new(
                    direction.X,
                    0,
                    direction.Z
                )

            if flatDirection.Magnitude > 0.001 then

                model:PivotTo(
                    CFrame.lookAt(
                        newPosition,
                        newPosition
                            + flatDirection
                    )
                )

            else

                local rotationOnly =
                    pivot
                    - pivot.Position

                model:PivotTo(
                    CFrame.new(newPosition)
                    * rotationOnly
                )

            end

            return false

        end

        -- ========================================================
        -- MAIN V3 MOVEMENT LOOP
        -- ========================================================

        connection =
            RunService.Heartbeat:Connect(
                function(dt)

                    if not entity:IsAlive()
                        or not model.Parent
                    then

                        connection:Disconnect()
                        return

                    end

                    if model:GetAttribute(
                        "BeingBanished"
                    ) then
                        return
                    end

                    -- =================================================
                    -- GET CURRENT ROOMS
                    -- =================================================

                    local entityRoom =
                        GetRoomAtPoint(
                            model:GetPivot().Position
                        )

                    local playerRoom =
                        GetPlayerRoom()

                    -- =================================================
                    -- SAME ROOM = WALL CHASE
                    -- =================================================

                    if entityRoom
                        and playerRoom
                        and entityRoom == playerRoom
                    then

                        if not directChasing then

                            directChasing = true

                            -- Throw away the current V3 node route.
                            table.clear(nodes)
                            nodeIndex = 1

                        end

                        ChasePlayer(dt)

                    else

                        -- =============================================
                        -- PLAYER IS IN ANOTHER ROOM
                        -- =============================================

                        if directChasing then

                            directChasing = false

                            -- Player entered a new room.
                            -- Build a completely new route toward them.
                            BuildRoute()

                        elseif #nodes == 0 then

                            -- Initial route.
                            BuildRoute()

                        end

                        -- =============================================
                        -- FOLLOW V3 NODE ROUTE
                        -- =============================================

                        if not directChasing
                            and #nodes > 0
                        then

                            local node =
                                nodes[nodeIndex]

                            if MoveToNode(
                                node,
                                dt
                            ) then

                                nodeIndex =
                                    nodeIndex + 1

                                if nodeIndex
                                    > #nodes
                                then

                                    -- Route is finished.
                                    -- Rebuild it toward the
                                    -- player's latest room.
                                    BuildRoute()

                                end

                            end

                        end

                    end

                    -- =================================================
                    -- DESPAWN TIMER
                    -- =================================================

                    if despawnTime > 0
                        and (
                            os.clock()
                            - startTime
                        ) >= despawnTime
                    then

                        connection:Disconnect()

                        if not model:GetAttribute(
                            "Despawning"
                        ) then

                            model:SetAttribute(
                                "Despawning",
                                true
                            )

                            task.spawn(
                                entity.RunCallback,
                                entity,
                                "OnDespawning"
                            )

                            local sinkTarget =
                                model:GetPivot().Position
                                - Vector3.new(
                                    0,
                                    300,
                                    0
                                )

                            local sinkConnection

                            sinkConnection =
                                RunService.Heartbeat:Connect(
                                    function(dt2)

                                        if not model.Parent then
                                            sinkConnection:Disconnect()
                                            return
                                        end

                                        local pivot =
                                            model:GetPivot()

                                        local difference =
                                            sinkTarget
                                            - pivot.Position

                                        if difference.Magnitude <= 2 then

                                            sinkConnection:Disconnect()

                                            entity:Despawn()

                                            return

                                        end

                                        model:PivotTo(
                                            pivot
                                            + difference.Unit
                                            * math.min(
                                                speed
                                                    * dt2
                                                    * 1.8,
                                                difference.Magnitude
                                            )
                                        )

                                    end
                                )

                        end

                    end

                end
            )

    end)
end
  
    getgenv().VynixuEntitySpawnerV3 =      
        Brain      
  
    return entity  
  
end  
  
--// current entity //--  
  
function Brain.GetCurrentEntity()  
  
    return CurrentEntity  
  
end  
  
--// active state //--  
  
function Brain.IsActive()  
  
    return EntityActive  
  
end  
  
--// despawn //--  
  
function Brain.Despawn()  
  
    local entity =      
        CurrentEntity      
  
    if entity then      
  
        pcall(function()      
            entity:Despawn()      
        end)      
  
    end      
  
    EntityActive = false      
  
    CurrentEntity = nil  
  
end  
  
--// global //--  
  
getgenv().VynixuEntitySpawnerV3 =      
    Brain  
  
return Brain
