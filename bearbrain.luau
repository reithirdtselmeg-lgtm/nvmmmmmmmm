-- SkinBrain v1.0
-- the boring work: downloads/caching, frame logic, billboard, effects, cleanup.
-- you never need to edit this. all settings live in SkinTemplate.lua.
-- put this file in your executor's workspace folder as "SkinBrain.lua".

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local env = (getgenv and getgenv()) or _G
local TAG = "[SkinBrain] "
local Brain = {Version = "1.0"}

-- --- DEFAULTS ---
local DEFAULTS = {
    SkinName = "Skin",

    -- sprites (rbxassetid / number / link). lists, any amount of frames
    Idle = {},
    Walk = {},
    IdleFrameSwitchSpeed = 0.25,   -- seconds per idle frame
    IdleFrameCycle = false,
    WalkFrameCycle = false,

    -- billboard
    sizeX = 3.2,
    sizeY = 7,
    studsOffsetY = 0.25,
    Tint = Color3.new(1, 1, 1),
    Transparency = 0,
    LightInfluence = 1,
    AlwaysOnTop = false,
    HideCharacter = false,
    RemoveOtherBillboards = true,

    -- effects
    FrameJiggle = false,
    FrameJiggleStrength = 0.12,    -- how much it squashes (0.12 = down to 88% height)
    FrameJiggleEase = 2,           -- 1 = even squash across the frame, higher = snaps right before the change

    GlitchEffect = false,
    GlitchStrength = 0.4,
    GlitchRate = 20,

    RainbowKeyframeColor = false,
    RainbowSpeed = 3,

    AfterimageEffect = false,
    AfterimageWalkRate = 0.06,
    AfterimageIdleRate = 0.18,
    AfterimageMax = 40,
    AfterimageFadeTime = 0.75,
    AfterimageTransparency = 0.4,
    AfterimageDistort = true,

    -- downloads
    ForceRedownload = false,
    DownloadTimeout = 20,
}
-- settings that are allowed to be nil (so they aren't flagged as typos)
local OPTIONAL = {WalkFrameSwitchSpeed = true, ThemeSound = true, PointLightModifier = true}

local function buildConfig(user)
    local cfg = {}
    for k, v in pairs(user or {}) do
        if DEFAULTS[k] == nil and not OPTIONAL[k] then
            warn(TAG .. "unknown setting '" .. tostring(k) .. "' (typo?)")
        end
        cfg[k] = v
    end
    for k, v in pairs(DEFAULTS) do
        if cfg[k] == nil then cfg[k] = v end
    end
    if typeof(cfg.Tint) ~= "Color3" then cfg.Tint = Color3.new(1, 1, 1) end
    return cfg
end

-- --- EXECUTOR FUNCTIONS ---
local request = (syn and syn.request) or (http and http.request) or http_request or request
local customAsset = getcustomasset or getsynasset
local CACHE_DIR = "SkinBrain"

-- --- SOURCE HANDLING ---
local function normalize(src)
    if type(src) == "number" then return "rbxassetid://" .. math.floor(src) end
    if type(src) ~= "string" then return nil end
    src = src:match("^%s*(.-)%s*$")
    if src == "" then return nil end
    if src:match("^%d+$") then return "rbxassetid://" .. src end
    return src
end

local function isRobloxAsset(src)
    return src:match("^rbxassetid://") ~= nil
        or src:match("^rbxasset://") ~= nil
        or src:match("^rbxthumb://") ~= nil
        or src:find("roblox%.com/asset", 1, false) ~= nil
end

local function isLink(src)
    return src:match("^https?://") ~= nil
end

local function hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%08x"):format(h)
end

local ALLOWED_EXT = {png = true, jpg = true, jpeg = true, webp = true, mp3 = true, ogg = true, wav = true}

local function guessExt(url, kind)
    local clean = url:gsub("[%?#].*$", "")
    local ext = clean:match("%.(%w+)$")
    ext = ext and ext:lower()
    if ext and ALLOWED_EXT[ext] then return ext end
    return kind == "audio" and "mp3" or "png"
end

local function looksValid(ext, body)
    if ext == "png" then return body:sub(2, 4) == "PNG" end
    if ext == "jpg" or ext == "jpeg" then return body:byte(1) == 0xFF and body:byte(2) == 0xD8 end
    if ext == "webp" or ext == "wav" then return body:sub(1, 4) == "RIFF" end
    if ext == "ogg" then return body:sub(1, 4) == "OggS" end
    if ext == "mp3" then
        return body:sub(1, 3) == "ID3" or (body:byte(1) == 0xFF and (body:byte(2) or 0) >= 0xE0)
    end
    return true
end

-- downloads (or reuses cached) a link, returns a getcustomasset string or nil
local function fetch(url, kind, cfg)
    if not (request and writefile and isfile and customAsset) then
        warn(TAG .. "executor can't download links (missing request/writefile/getcustomasset): " .. url)
        return nil
    end
    if makefolder and isfolder and not isfolder(CACHE_DIR) then pcall(makefolder, CACHE_DIR) end
    local base = (isfolder and isfolder(CACHE_DIR)) and (CACHE_DIR .. "/") or ""

    local ext = guessExt(url, kind)
    local safeName = tostring(cfg.SkinName or "Skin"):gsub("[^%w_%-]", "_")
    -- the url hash is in the filename, so changing a link automatically downloads fresh
    local path = ("%s%s_%s.%s"):format(base, safeName, hash(url), ext)

    if cfg.ForceRedownload or not isfile(path) then
        local ok, res = pcall(request, {Url = url, Method = "GET"})
        if ok and res and res.Body and #res.Body > 0
            and (res.Success or res.StatusCode == 200) and looksValid(ext, res.Body) then
            pcall(writefile, path, res.Body)
        else
            warn(TAG .. "download failed or wasn't a real " .. ext .. " file: " .. url)
            return nil
        end
    end

    local ok, asset = pcall(customAsset, path)
    if ok and asset then return asset end
    return nil
end

-- resolves every source in parallel; returns map src -> usable asset string (or false)
local function resolveAll(entries, cfg)
    local out, pending = {}, 0
    for _, e in ipairs(entries) do
        local src = e.src
        if out[src] == nil then
            out[src] = false
            if isRobloxAsset(src) then
                out[src] = src
            elseif isLink(src) then
                pending += 1
                task.spawn(function()
                    out[src] = fetch(src, e.kind, cfg) or false
                    pending -= 1
                end)
            else
                warn(TAG .. "can't use '" .. src .. "' (use rbxassetid://..., a number, or an http(s) link)")
            end
        end
    end
    local deadline = os.clock() + cfg.DownloadTimeout
    while pending > 0 and os.clock() < deadline do task.wait(0.05) end
    return out
end

local function toList(v)
    if v == nil then return {} end
    if type(v) ~= "table" then return {v} end
    return v
end

-- frame picker. cycle = ping-pong (1,2,3,2,1,2,3...) so no frame ever shows twice in a row
local function pickFrame(frames, t, speed, cycle)
    local n = #frames
    if n == 1 then return frames[1] end
    local step = math.floor(t / math.max(speed, 0.01))
    local idx
    if cycle and n > 2 then
        local period = 2 * n - 2
        local p = step % period
        idx = (p < n) and (p + 1) or (period - p + 1)
    else
        idx = (step % n) + 1
    end
    return frames[idx]
end

local function mulColor(a, b)
    return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
end

-- --- RUN ---
function Brain.Run(userCfg)
    -- re-execute guard
    if env.__SkinBrainCleanup then
        pcall(env.__SkinBrainCleanup)
        env.__SkinBrainCleanup = nil
    end

    local cfg = buildConfig(userCfg)
    local plr = Players.LocalPlayer
    local char = plr.Character or plr.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    local humanoid = char:WaitForChild("Humanoid")

    -- collect + resolve all sources
    local entries = {}
    local function collect(list, kind)
        local res = {}
        for _, s in ipairs(toList(list)) do
            local n = normalize(s)
            if n then
                res[#res + 1] = n
                entries[#entries + 1] = {src = n, kind = kind}
            end
        end
        return res
    end
    local idleSrc = collect(cfg.Idle, "image")
    local walkSrc = collect(cfg.Walk, "image")
    local theme = cfg.ThemeSound
    local themeSrc = theme and normalize(theme.Id)
    if themeSrc then entries[#entries + 1] = {src = themeSrc, kind = "audio"} end

    local resolved = resolveAll(entries, cfg)

    local function frames(srcList)
        local out = {}
        for _, s in ipairs(srcList) do
            if resolved[s] then out[#out + 1] = resolved[s] end
        end
        return out
    end
    local idle, walk = frames(idleSrc), frames(walkSrc)
    if #idle == 0 and #walk > 0 then idle = {walk[1]} end
    if #walk == 0 then walk = idle end
    warn(("%sloaded '%s': %d idle frame(s), %d walk frame(s)"):format(TAG, cfg.SkinName, #idle, #walk))
    if #idle == 0 then
        warn(TAG .. "no usable sprites loaded, nothing to show")
        return nil
    end
    if not char:IsDescendantOf(game) then return nil end

    local alive = true
    local conns, sounds = {}, {}

    if cfg.RemoveOtherBillboards then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BillboardGui") then d:Destroy() end
        end
    end

    -- billboard + sprite
    local gui = Instance.new("BillboardGui")
    gui.Name = "SkinBrainBillboard"
    gui.ResetOnSpawn = false
    gui.AlwaysOnTop = cfg.AlwaysOnTop
    gui.LightInfluence = cfg.LightInfluence
    gui.Size = UDim2.new(cfg.sizeX, 0, cfg.sizeY, 0)
    gui.StudsOffset = Vector3.new(0, cfg.studsOffsetY, 0)
    gui.Parent = root

    local sprite = Instance.new("ImageLabel")
    sprite.Name = "Sprite"
    sprite.AnchorPoint = Vector2.new(0.5, 1)   -- bottom edge stays put when squashing
    sprite.Position = UDim2.new(0.5, 0, 1, 0)
    sprite.Size = UDim2.new(1, 0, 1, 0)
    sprite.BackgroundTransparency = 1
    sprite.ImageColor3 = cfg.Tint
    sprite.ImageTransparency = cfg.Transparency
    sprite.ZIndex = 2
    sprite.Image = idle[1]
    sprite.Parent = gui

    -- preload (non-blocking: some executors hang PreloadAsync on custom files)
    local preloadFolder = Instance.new("Folder")
    preloadFolder.Name = "Preload"
    preloadFolder.Parent = gui
    local labels, seen = {}, {}
    for _, set in ipairs({idle, walk}) do
        for _, id in ipairs(set) do
            if not seen[id] then
                seen[id] = true
                local lbl = Instance.new("ImageLabel")
                lbl.Size = UDim2.new(0, 1, 0, 1)
                lbl.Image = id
                lbl.ImageTransparency = 0.99
                lbl.BackgroundTransparency = 1
                lbl.Parent = preloadFolder
                labels[#labels + 1] = lbl
            end
        end
    end
    do
        local finished = false
        task.spawn(function()
            pcall(ContentProvider.PreloadAsync, ContentProvider, labels)
            finished = true
        end)
        local t0 = os.clock()
        while not finished and os.clock() - t0 < 2 do task.wait(0.05) end
    end

    -- afterimage holder + pool
    local trailHolder
    local trailPool, activeTrails = {}, 0
    if cfg.AfterimageEffect then
        trailHolder = Instance.new("Folder")
        trailHolder.Name = "SkinBrainTrails"
        trailHolder.Parent = workspace
    end

    local currentColor = cfg.Tint
    local state = {moving = false}

    local function acquireTrail()
        local t = table.remove(trailPool)
        if t then return t end
        local part = Instance.new("Part")
        part.Size = Vector3.new(1, 1, 1)
        part.Transparency = 1
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Anchored = true
        local tgui = Instance.new("BillboardGui")
        tgui.AlwaysOnTop = cfg.AlwaysOnTop
        tgui.LightInfluence = cfg.LightInfluence
        tgui.Parent = part
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.new(1, 0, 1, 0)
        img.BackgroundTransparency = 1
        img.ZIndex = 0
        img.Parent = tgui
        return {part = part, gui = tgui, img = img}
    end

    local function spawnAfterimage(texture, moving)
        if texture == "" or activeTrails >= cfg.AfterimageMax then return end
        local t = acquireTrail()
        activeTrails += 1

        t.part.CFrame = root.CFrame * CFrame.new(0, cfg.studsOffsetY, moving and -0.6 or -0.4)

        if cfg.AfterimageDistort then
            t.gui.Size = UDim2.new(
                cfg.sizeX * (math.random(70, 115) / 100), 0,
                cfg.sizeY * (math.random(75, 110) / 100), 0
            )
        else
            t.gui.Size = UDim2.new(cfg.sizeX, 0, cfg.sizeY, 0)
        end

        t.img.Image = texture
        t.img.ImageColor3 = currentColor
        t.img.ImageTransparency = cfg.AfterimageTransparency
        t.part.Parent = trailHolder

        local fade = cfg.AfterimageFadeTime * (moving and 1 or 1.33)
        local tween = TweenService:Create(
            t.img,
            TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {ImageTransparency = 1}
        )
        tween.Completed:Once(function()
            t.part.Parent = nil
            activeTrails -= 1
            trailPool[#trailPool + 1] = t
        end)
        tween:Play()
    end

    -- hide the real character (optional)
    local hiddenParts = {}
    if cfg.HideCharacter then
        local function track(d)
            if d:IsA("BasePart") then hiddenParts[#hiddenParts + 1] = d end
        end
        for _, d in ipairs(char:GetDescendants()) do track(d) end
        conns[#conns + 1] = char.DescendantAdded:Connect(track)
    end

    -- theme sound (optional)
    if themeSrc and resolved[themeSrc] then
        local s = Instance.new("Sound")
        s.Name = "SkinBrainTheme"
        s.SoundId = resolved[themeSrc]
        s.Volume = theme.Volume or 1
        s.Looped = true -- always loops until you reset/respawn
        if theme.RollOffMaxDistance then s.RollOffMaxDistance = theme.RollOffMaxDistance end
        s.Parent = root
        sounds[#sounds + 1] = s
        s:Play()

        -- watchdog: if anything stops/pauses it, start it again
        task.spawn(function()
            while alive and s.Parent do
                s.Looped = true
                if not s.Playing then s:Play() end
                task.wait(1)
            end
        end)
    end

    -- PointLight modifier (optional, finds a PointLight inside your character)
    local pl = cfg.PointLightModifier
    local lightRef, lightOriginal
    if pl and pl.Enabled then
        task.spawn(function()
            local deadline = os.clock() + 6
            local light = char:FindFirstChildWhichIsA("PointLight", true)
            while not light and alive and os.clock() < deadline do
                task.wait(0.25)
                light = char:FindFirstChildWhichIsA("PointLight", true)
            end
            if not (light and alive) then
                if alive then warn(TAG .. "PointLightModifier: no PointLight found in your character") end
                return
            end
            lightOriginal = {
                Color = light.Color, Brightness = light.Brightness,
                Range = light.Range, Enabled = light.Enabled,
            }
            if pl.Color then light.Color = pl.Color end
            if pl.Brightness then light.Brightness = pl.Brightness end
            if pl.Range then light.Range = pl.Range end
            light.Enabled = true
            lightRef = light
        end)
    end

    -- main loop
    local walkSpeed = cfg.WalkFrameSwitchSpeed or 0.125 -- 0.125 == math.floor(walkTime * 8) % 2
    local walkTime, idleTime = 0, 0
    local activeTexture = idle[1]
    local squashY = 1
    local glitch = {x = 0, y = 0, z = 0, rot = 0, scale = 1}
    local nextGlitch, lastTrail = 0, 0

    conns[#conns + 1] = RunService.RenderStepped:Connect(function(dt)
        local now = os.clock()
        local moving = humanoid.MoveDirection.Magnitude > 0
        state.moving = moving

        if moving then
            walkTime += dt
            idleTime = 0
        else
            idleTime += dt
            walkTime = 0
        end

        -- frames
        local tex
        if moving then
            tex = pickFrame(walk, walkTime, walkSpeed, cfg.WalkFrameCycle)
        else
            tex = pickFrame(idle, idleTime, cfg.IdleFrameSwitchSpeed, cfg.IdleFrameCycle)
        end
        if tex ~= activeTexture then
            activeTexture = tex
            sprite.Image = tex
        end

        -- rainbow (multiplied by Tint)
        if cfg.RainbowKeyframeColor then
            local hue = (now / math.max(cfg.RainbowSpeed, 0.05)) % 1
            currentColor = mulColor(Color3.fromHSV(hue, 1, 1), cfg.Tint)
            sprite.ImageColor3 = currentColor
        end

        -- frame jiggle: squash toward the bottom edge right before one frame change,
        -- stretch back to normal right before the next, looping. walking only.
        if cfg.FrameJiggle then
            if moving then
                local step = walkTime / math.max(walkSpeed, 0.01)
                local whole = math.floor(step)
                local e = (step - whole) ^ math.max(cfg.FrameJiggleEase, 0.1)
                local amt = cfg.FrameJiggleStrength
                if whole % 2 == 0 then
                    squashY = 1 - amt * e          -- normal -> squashed
                else
                    squashY = 1 - amt * (1 - e)    -- squashed -> normal
                end
            else
                -- stopped walking: settle back to normal and stay there
                squashY = squashY + (1 - squashY) * math.min(1, dt * 18)
            end
        end

        -- glitch
        if cfg.GlitchEffect and now >= nextGlitch then
            nextGlitch = now + 1 / math.max(cfg.GlitchRate, 1)
            local s = cfg.GlitchStrength
            glitch.x = (math.random() * 2 - 1) * s
            glitch.y = (math.random() * 2 - 1) * s
            glitch.z = (math.random() * 2 - 1) * s
            glitch.rot = (math.random() * 2 - 1) * s * 10
            glitch.scale = 1 + (math.random() * 2 - 1) * s * 0.15
        end
        if cfg.FrameJiggle or cfg.GlitchEffect then
            sprite.Rotation = glitch.rot
            sprite.Size = UDim2.new(glitch.scale, 0, glitch.scale * squashY, 0)
            gui.StudsOffset = Vector3.new(glitch.x, cfg.studsOffsetY + glitch.y, glitch.z)
        end

        -- afterimages
        if cfg.AfterimageEffect then
            local rate = moving and cfg.AfterimageWalkRate or cfg.AfterimageIdleRate
            if now - lastTrail >= rate then
                lastTrail = now
                spawnAfterimage(activeTexture, moving)
            end
        end

        -- point light follows skin color (optional)
        if lightRef and pl and pl.FollowSkinColor then
            lightRef.Color = currentColor
        end

        -- hide the real character
        for i = 1, #hiddenParts do
            hiddenParts[i].LocalTransparencyModifier = 1
        end
    end)

    -- cleanup (gone for good on reset/respawn, never comes back)
    local function destroy()
        if not alive then return end
        alive = false
        for _, c in ipairs(conns) do c:Disconnect() end
        for _, s in ipairs(sounds) do s:Destroy() end
        for i = 1, #hiddenParts do
            pcall(function() hiddenParts[i].LocalTransparencyModifier = 0 end)
        end
        if lightRef and lightOriginal and lightRef.Parent then
            pcall(function()
                lightRef.Color = lightOriginal.Color
                lightRef.Brightness = lightOriginal.Brightness
                lightRef.Range = lightOriginal.Range
                lightRef.Enabled = lightOriginal.Enabled
            end)
        end
        gui:Destroy()
        if trailHolder then trailHolder:Destroy() end
        if env.__SkinBrainCleanup == destroy then env.__SkinBrainCleanup = nil end
    end

    conns[#conns + 1] = char.AncestryChanged:Connect(function()
        if not char:IsDescendantOf(game) then destroy() end
    end)
    conns[#conns + 1] = humanoid.Died:Connect(destroy)

    env.__SkinBrainCleanup = destroy
    return {Destroy = destroy}
end

env.SkinBrain = Brain
return Brain