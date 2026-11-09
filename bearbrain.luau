-- SkinBrain v3.12
-- the boring work: downloads/caching, frame logic, billboard, effects, cleanup.
-- you never need to edit this. all settings live in SkinTemplate.lua.
-- host it (github raw link) or put it in your executor's workspace as "SkinBrain.lua".

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local env = (getgenv and getgenv()) or _G
local TAG = "[SkinBrain] "
local Brain = {Version = "3.12"}

-- --- DEFAULTS ---
local DEFAULTS = {
    SkinName = "Skin",

    -- sprites (rbxassetid / number / link). lists, any amount of frames
    Idle = {},
    Walk = {},
    StepDelay = 0.2,               -- seconds each frame is shown (the in-game skin system's StepDelay). idle/walk can override it
    FrameMode = "auto",            -- auto = idle when you stand still, walk when you move (like the game) | idle = always idle frames | walk = always walk frames | reverse = the opposite of auto
    MoveDetection = "game",        -- game = like the real skin system (Humanoid.Running speed above WalkMagnitude) | input = any move input
    WalkMagnitude = 0.1,           -- running speed (studs/second) above which you count as walking (MoveDetection = "game")
    IdleFrameDelays = {},          -- optional seconds for each idle frame, like the game's per-frame StepDelay: {0.3, 0.1, ...}
    WalkFrameDelays = {},          -- same for walk frames. missing or 0 entries use the normal delay
    IdleFrameCycle = false,
    WalkFrameCycle = false,
    ScaleWalkWithSpeed = false,    -- walk animation speeds up/slows down with your real speed

    -- billboard
    sizeX = 7,
    sizeY = 7,
    studsOffsetY = 0.25,
    studsOffsetX = 0,              -- sideways offset of the skin (rarely needed)
    studsOffsetZ = 0,              -- depth offset: positive = nearer the camera
    Tint = Color3.new(1, 1, 1),
    Transparency = 0,
    LightInfluence = 1,
    AlwaysOnTop = false,
    PixelArt = false,              -- crisp pixels instead of smoothed
    HideCharacter = false,
    HideNameTag = false,
    RemoveOtherBillboards = true,
    Brightness = 1,                -- brightness of the main skin billboard (above 1 = brighter)

    -- effects
    FrameJiggle = false,
    FrameJiggleStrength = 0.03,    -- how much it squashes (0.12 = down to 88% height)
    FrameJiggleEase = 1.5,           -- 1 = even squash across the frame, higher = snaps right before the change
    FrameSkipJiggle = {},          -- walk frame numbers (1 = first walk sprite) that do NOT trigger the jiggle. empty = none skipped

    FrameJump = false,             -- a little visual hop on every walk frame (only the sprite moves, NOT a real jump)
    FrameJumpHighestHeight = 1.5708, -- how high each hop goes, in studs (the in-game bounce height is pi/2 = 1.5708)
    FrameSkipJump = {},            -- walk frame numbers (1 = first walk sprite) that do NOT hop. empty = none skipped
    FrameSkipStomp = {},           -- walk frame numbers (1 = first walk sprite) that stay silent (no footstep). empty = none skipped
    FrameSwayAmount = 0,           -- degrees: the sprite sways left/right on alternate walk steps (the game's SwayAmount). 0 = off
    FrameBounceStyle = "step",     -- which of the game's two bounce systems: step = BouncePerStep (hops once every walk step) | alternate = BouncePerStep2 (rises on odd walk frames, falls on even ones, sway rocks side to side)

    GlitchEffect = false,
    GlitchStrength = 0.1,
    GlitchRate = 20,

    SliceGlitch = false,           -- horizontal slicing: the sprite is cut into strips and random strips slide left and right
    SliceCount = 24,               -- how many horizontal strips
    SliceStrength = 0.12,          -- how far a strip can slide, as a fraction of the sprite's width
    SliceSpeed = 3,                -- how fast strips swing back and forth (swings per second)
    SliceChance = 0.5,             -- chance (0 to 1) that a strip is sliding at any moment
    SliceRerollTime = 0.25,        -- seconds between re-picking which strips slide
    SliceGapChance = 0,            -- chance a sliding strip drops out completely (the dashed-line look). 0 = never

    RainbowKeyframeColor = false,
    RainbowSpeed = 10,

    AfterimageEffect = false,
    AfterimageRate = 0.15,         -- seconds between ghosts
    AfterimageMax = 40,
    AfterimageFadeTime = 0.5,      -- particle lifetime in seconds (TBB's emitter uses 0.5)
    AfterimageTransparency = 0.4,
    AfterimageDistort = true,
    AfterimageDistortAmount = 0.15, -- how much each ghost is squashed/stretched and enlarged (0.15 = up to ~15%)
    AfterimageDistortRotation = 0, -- random tilt per ghost in degrees (0 = none)
    AfterimageFollowFrame = false, -- true = like TBB: every ghost always shows the billboard's CURRENT frame (no texture swapping, so no flicker)
    AfterimageSizeScale = 0.5,     -- multiplies the size of each ghost
    AfterimageGrow = 0,            -- 0 = ghosts keep their size and just fade out. 0.2 = they grow 20% by the end
    AfterimageLightEmission = 0.5, -- 0 = normal, 1 = glowing/additive (great with rainbow)
    AfterimageBrightness = 1,      -- brightness of the afterimage particles (above 1 = brighter)
    AfterimageZOffset = -0.5,      -- render depth of ghosts: negative = behind the sprite, 0 = same depth, positive = in front

    WobbleEffect = false,          -- sprite tilts side to side
    WobbleStrength = 6,            -- degrees
    WobbleSpeed = 1.6,             -- sways per second
    WobbleWhenIdle = false,        -- false = only while walking

    HoverBob = false,              -- floats up and down
    HoverHeight = 0.3,             -- studs
    HoverSpeed = 0.6,              -- bobs per second
    HoverOnlyWhenIdle = false,     -- true = only bobs while standing still

    BreathEffect = false,          -- gentle squash/stretch while standing still
    BreathStrength = 0.03,
    BreathSpeed = 0.4,

    GhostPulse = false,            -- fades in and out slowly
    GhostPulseMin = 0.3,           -- how visible it gets at its faintest (0 = fully gone, 1 = no pulse)
    GhostPulseSpeed = 0.35,        -- pulses per second

    FlickerEffect = false,         -- random blinks, like unstable data
    FlickerRate = 1.5,             -- average flickers per second
    FlickerDuration = 0.08,        -- seconds per flicker
    FlickerDepth = 0.85,           -- how invisible it gets during a flicker

    BoilEffect = false,            -- choppy hand-drawn jitter
    BoilStrength = 1.5,
    BoilRate = 8,                  -- jitters per second

    -- billboard layers: copies of the sprite drawn behind it
    ShadowEffect = false,          -- dark copy offset behind the sprite
    ShadowOffsetX = 0.03,          -- fraction of the sprite size
    ShadowOffsetY = 0.03,
    ShadowColor = Color3.new(0, 0, 0),
    ShadowTransparency = 0.55,

    RGBSplit = false,              -- red/blue color-split copies either side of the sprite
    RGBSplitAmount = 0.03,         -- fraction of the sprite size

    -- global color correction, applied to every color setting (Tint, shadow/outline/aura, orbs, light).
    -- 1 = off. if colors come out more saturated/brighter than the one you picked, lower these
    ColorSaturation = 1,           -- e.g. 0.6 = 40% less saturated
    ColorBrightness = 1,           -- e.g. 0.9 = 10% darker

    -- TBB-style scare event: every ScareInterval seconds an image flashes over your skin and a sound plays.
    -- the scare ends when the sound ends
    ScareEvent = false,
    ScareInterval = 24,            -- seconds between scares (from the start of one to the start of the next)
    ScareRemoveBear = false,       -- true = your main skin billboard is hidden during the scare, then comes back
    ScareRemoveAfterimage = false, -- true = the afterimage is hidden during the scare, then comes back
    ScareImage = "https://static.wikia.nocookie.net/roblox-bear-content/images/9/90/TBB_Classic_Scare1.png/revision/latest/scale-to-width-down/185?cb=20260211113902",
    ScareSizeX = 7,                -- the scare image has its own billboard size...
    ScareSizeY = 7,
    ScareStudsOffsetX = 0,         -- ...and its own offset (Z: positive = in front of your skin)
    ScareStudsOffsetY = 0.25,
    ScareStudsOffsetZ = 1,
    ScareBrightness = 1,           -- brightness of the scare image
    ScareSound = "https://imgg.fr/r/pCyKOKME.mp3",
    ScareVolume = 4,
    ScareFallbackTime = 2,         -- seconds the scare lasts if the sound can't play
    ScareMainWeight = 1,           -- how likely the main scare (ScareImage / ScareSound) is picked among the ScareVariants (0 = never)
    ScarePick = "random",          -- random (never the same scare twice in a row) | order (cycles through them)
    ScareShake = 0,                -- studs the scare image shakes (each variant can set its own Shake)

    -- phases: your skin changes phase every time the scare event happens (needs ScareEvent). see Phases in the template
    PhaseSystem = false,
    PhaseChangeAt = "start",       -- start = the phase changes the moment a scare begins | end = when it ends
    PhaseBlendTime = 0,            -- seconds to smoothly blend size / offset / color into the new phase (0 = instant)
    PhaseAudioFade = 0.5,          -- seconds the theme music crossfades when the phase changes

    -- downloads / logging
    ForceRedownload = false,
    DownloadTimeout = 20,
    DownloadRetries = 2,
    AllowUnsupportedFormats = true, -- try webp/gif anyway if a link only gives those (roblox may not draw them)
    ConvertGifs = true,            -- gif links are split into png frames automatically (roblox can't play gifs)
    GifMaxFrames = 75,             -- gifs longer than this are cut off
    GifMaxSize = 770,              -- gifs wider/taller than this (pixels) are refused, shrink them first
    DeleteDownloadsOnRemove = false, -- true = delete the downloaded files when the skin is removed (reset/respawn)
    Debug = true,                  -- false = only print problems
    DebugFrames = false,           -- prints the walk frame number every time it changes, and whether hop/jiggle/stomp fire on it
}
-- settings that are allowed to be nil (so they aren't flagged as typos)
local OPTIONAL = {WalkFrameSwitchSpeed = true, IdleFrameSwitchSpeed = true, ThemeSound = true, PointLightModifier = true,
    VoiceLines = true, StompSound = true, OrbOrbit = true, ExtraBillboards = true, ThemeSound2 = true, ReactiveSounds = true, ScareVariants = true, Phases = true, PhaseStart = true, SkinZip = true}

-- scales a color's saturation/brightness (see ColorSaturation / ColorBrightness)
local function fixColor(c, cfg)
    if typeof(c) ~= "Color3" then return c end
    local sat, bri = cfg.ColorSaturation or 1, cfg.ColorBrightness or 1
    if sat == 1 and bri == 1 then return c end
    local h, sv, v = c:ToHSV()
    return Color3.fromHSV(h, math.clamp(sv * sat, 0, 1), math.clamp(v * bri, 0, 1))
end

-- alternate spellings that are accepted for a few settings
local ALIASES = {
    Scareremovebear = "ScareRemoveBear", Scareremoveafterimage = "ScareRemoveAfterimage",
    Scareimage = "ScareImage", Scaresound = "ScareSound", Scareevent = "ScareEvent",
}

local function buildConfig(user)
    local cfg = {}
    for k, v in pairs(user or {}) do
        k = ALIASES[k] or k
        if DEFAULTS[k] == nil and not OPTIONAL[k] then
            warn(TAG .. "unknown setting '" .. tostring(k) .. "' (typo?)")
        end
        cfg[k] = v
    end
    for k, def in pairs(DEFAULTS) do
        local want = typeof(def)
        if cfg[k] == nil then
            cfg[k] = def
        elseif want ~= "table" and typeof(cfg[k]) ~= want then
            warn(("%s'%s' should be a %s, using the default (%s)"):format(TAG, k, want, tostring(def)))
            cfg[k] = def
        end
    end
    cfg.Transparency = math.clamp(cfg.Transparency, 0, 1)
    cfg.LightInfluence = math.clamp(cfg.LightInfluence, 0, 1)
    cfg.AfterimageMax = math.max(math.floor(cfg.AfterimageMax), 0)
    cfg.AfterimageSizeScale = math.max(cfg.AfterimageSizeScale, 0.05)
    cfg.AfterimageLightEmission = math.clamp(cfg.AfterimageLightEmission, 0, 1)
    cfg.GhostPulseMin = math.clamp(cfg.GhostPulseMin, 0, 1)
    cfg.FrameJumpHighestHeight = math.max(cfg.FrameJumpHighestHeight, 0)
    cfg.AfterimageDistortAmount = math.clamp(cfg.AfterimageDistortAmount, 0, 1)
    cfg.StepDelay = math.max(cfg.StepDelay, 0.02)
    cfg.Brightness = math.max(cfg.Brightness, 0)
    cfg.AfterimageBrightness = math.max(cfg.AfterimageBrightness, 0)
    cfg.ScareBrightness = math.max(cfg.ScareBrightness, 0)
    cfg.ScareInterval = math.max(cfg.ScareInterval, 1)
    cfg.ScareVolume = math.clamp(cfg.ScareVolume, 0, 10)
    cfg.ScareFallbackTime = math.max(cfg.ScareFallbackTime, 0.2)
    cfg.ScareMainWeight = math.max(cfg.ScareMainWeight, 0)
    cfg.ScareShake = math.max(cfg.ScareShake, 0)
    cfg.PhaseBlendTime = math.max(cfg.PhaseBlendTime, 0)
    cfg.PhaseAudioFade = math.max(cfg.PhaseAudioFade, 0)
    cfg.PhaseChangeAt = (tostring(cfg.PhaseChangeAt):lower() == "end") and "end" or "start"
    cfg.ScarePick = (tostring(cfg.ScarePick):lower() == "order") and "order" or "random"
    cfg.WalkMagnitude = math.max(cfg.WalkMagnitude, 0)
    cfg.SliceCount = math.clamp(math.floor(cfg.SliceCount), 2, 200)
    cfg.SliceStrength = math.max(cfg.SliceStrength, 0)
    cfg.SliceChance = math.clamp(cfg.SliceChance, 0, 1)
    cfg.SliceGapChance = math.clamp(cfg.SliceGapChance, 0, 1)
    cfg.SliceRerollTime = math.max(cfg.SliceRerollTime, 0.05)
    local mode = tostring(cfg.FrameMode):lower()
    if mode ~= "auto" and mode ~= "idle" and mode ~= "walk" and mode ~= "reverse" then
        warn(TAG .. "FrameMode should be auto, idle, walk or reverse, using auto")
        mode = "auto"
    end
    cfg.FrameMode = mode
    cfg.FrameBounceStyle = (tostring(cfg.FrameBounceStyle):lower() == "alternate") and "alternate" or "step"
    cfg.MoveDetection = (tostring(cfg.MoveDetection):lower() == "input") and "input" or "game"
    cfg.ColorSaturation = math.max(cfg.ColorSaturation, 0)
    cfg.ColorBrightness = math.max(cfg.ColorBrightness, 0)
    cfg.Tint = fixColor(cfg.Tint, cfg)
    cfg.ShadowColor = fixColor(cfg.ShadowColor, cfg)
    if cfg.WalkFrameSwitchSpeed ~= nil and type(cfg.WalkFrameSwitchSpeed) ~= "number" then
        warn(TAG .. "WalkFrameSwitchSpeed should be a number or nil, using the default")
        cfg.WalkFrameSwitchSpeed = nil
    end
    if cfg.IdleFrameSwitchSpeed ~= nil and type(cfg.IdleFrameSwitchSpeed) ~= "number" then
        warn(TAG .. "IdleFrameSwitchSpeed should be a number or nil, using the default")
        cfg.IdleFrameSwitchSpeed = nil
    end
    return cfg
end

local function info(cfg, msg)
    if cfg.Debug then warn(TAG .. msg) end
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

-- a file you put in your executor's workspace folder yourself (a .png, .jpg or .zip)
local function isLocalFile(src)
    if not isfile or src:match("^rbx") then return false end
    local ok, found = pcall(isfile, src)
    return ok and found == true
end

local function hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%08x"):format(h)
end

local IMAGE_EXTS = {"png", "jpg", "webp", "gif"}
local AUDIO_EXTS = {"mp3", "ogg", "wav", "flac"}

-- headers that make sites (wikis/cdns) hand over the plain png instead of webp or a block page
local HEADERS = {
    ["User-Agent"] = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36",
    ["Accept"] = "image/png,image/jpeg,audio/mpeg,audio/ogg,application/zip,application/octet-stream,*/*;q=0.5",
}

-- detect the REAL file type from the bytes
-- links often lie about their extension
local function sniff(body)
    if type(body) ~= "string" or #body < 4 then
        return nil
    end

    -- PNG
    if body:sub(1, 8) == "\137PNG\r\n\26\n" then
        return "png"
    end

    -- JPEG
    if body:sub(1, 3) == "\255\216\255" then
        return "jpg"
    end

    -- GIF
    local gif = body:sub(1, 6)
    if gif == "GIF87a" or gif == "GIF89a" then
        return "gif"
    end

    -- ZIP (a zip of pngs)
    local zipSig = body:sub(1, 4)
    if zipSig == "PK\3\4" or zipSig == "PK\5\6" then
        return "zip"
    end

    -- OGG
    if body:sub(1, 4) == "OggS" then
        return "ogg"
    end

    -- FLAC
    if body:sub(1, 4) == "fLaC" then
        return "flac"
    end

    -- RIFF containers
    if body:sub(1, 4) == "RIFF" then
        local kind = body:sub(9, 12)

        -- WebP
        if kind == "WEBP" then
            return "webp"
        end

        -- WAV
        if kind == "WAVE" then
            return "wav"
        end
    end

    -- MP3 with ID3 metadata
    if body:sub(1, 3) == "ID3" then
        return "mp3"
    end

    -- MP3 frame header without ID3
    local b1, b2 = body:byte(1, 2)
    if b1 == 0xFF and b2 then
        local sync = b2 >= 0xE0
        if sync then
            return "mp3"
        end
    end

    return nil
end

-- formats roblox definitely supports
local function good(kind, ext, cfg)
    if ext == "zip" then return kind == "image" end -- a zip of pngs
    if kind == "audio" then
    return ext == "mp3"
        or ext == "ogg"
        or ext == "wav"
        or ext == "flac"
end
    if ext == "gif" and cfg and cfg.ConvertGifs then return true end -- we split gifs into png frames
    return ext == "png" or ext == "jpg"
end

-- formats we'll still try if nothing better is available
local function tolerated(kind, ext, cfg)
    return kind == "image" and cfg.AllowUnsupportedFormats and (ext == "webp" or ext == "gif")
end

-- fandom/wikia cdn serves webp by default; this flag asks it for the original png instead
local function wikiOriginal(url)
    if not (url:find("static.wikia.nocookie.net", 1, true) or url:find("vignette.wikia.nocookie.net", 1, true)) then
        return nil
    end
    if url:find("format=original", 1, true) then return nil end
    return url .. (url:find("?", 1, true) and "&" or "?") .. "format=original"
end

-- --- GIF DECODER ---
-- roblox can't play gifs, so a gif is decoded into separate png frames
-- (the brain then animates them like any other frame list)
local band, bor, bxor, lshift, rshift = bit32.band, bit32.bor, bit32.bxor, bit32.lshift, bit32.rshift
local unpack = table.unpack or unpack

local function rd16(s, p)
    local a, b = s:byte(p, p + 1)
    return (a or 0) + (b or 0) * 256
end

local CRC_TABLE
local function crcTable()
    if CRC_TABLE then return CRC_TABLE end
    CRC_TABLE = {}
    for i = 0, 255 do
        local c = i
        for _ = 1, 8 do
            if band(c, 1) == 1 then c = bxor(0xEDB88320, rshift(c, 1)) else c = rshift(c, 1) end
        end
        CRC_TABLE[i] = c
    end
    return CRC_TABLE
end

local function u32(n)
    return string.char(band(rshift(n, 24), 255), band(rshift(n, 16), 255), band(rshift(n, 8), 255), band(n, 255))
end

-- canvas = flat array of bytes, laid out exactly like raw png scanlines (filter byte 0, then RGBA per pixel)
local function encodePNG(w, h, canvas)
    local T = crcTable()
    local total = #canvas

    local ihdr = u32(w) .. u32(h) .. "\8\6\0\0\0"
    local crcI = 0xFFFFFFFF
    local ihdrFull = "IHDR" .. ihdr
    for i = 1, #ihdrFull do
        crcI = bxor(T[band(bxor(crcI, ihdrFull:byte(i)), 255)], rshift(crcI, 8))
    end
    crcI = bxor(crcI, 0xFFFFFFFF)

    local idat, idatLen = {}, 0
    local crc = 0xFFFFFFFF
    local function feedStr(str)
        for i = 1, #str do
            crc = bxor(T[band(bxor(crc, str:byte(i)), 255)], rshift(crc, 8))
        end
    end
    local function push(str)
        idat[#idat + 1] = str
        idatLen += #str
    end

    feedStr("IDAT")
    local zh = "\120\1" -- zlib header, no compression
    feedStr(zh)
    push(zh)

    local a, b = 1, 0
    local pos = 1
    while pos <= total do
        local n = math.min(65535, total - pos + 1)
        local last = pos + n - 1
        local final = (last >= total) and 1 or 0
        local nlen = bxor(n, 0xFFFF)
        local bh = string.char(final, band(n, 255), rshift(n, 8), band(nlen, 255), rshift(nlen, 8))
        feedStr(bh)
        push(bh)
        local i = pos
        while i <= last do
            local j = math.min(i + 3999, last)
            for k = i, j do
                local v = canvas[k]
                crc = bxor(T[band(bxor(crc, v), 255)], rshift(crc, 8))
                a += v
                b += a
            end
            push(string.char(unpack(canvas, i, j)))
            i = j + 1
        end
        a %= 65521
        b %= 65521
        pos += n
    end

    local adler = u32(b * 65536 + a)
    feedStr(adler)
    push(adler)
    crc = bxor(crc, 0xFFFFFFFF)

    return table.concat({
        "\137PNG\r\n\26\n",
        u32(13), "IHDR", ihdr, u32(crcI),
        u32(idatLen), "IDAT", table.concat(idat), u32(crc),
        "\0\0\0\0IEND\174\66\96\130",
    })
end

local function readPalette(data, pos, bits)
    local size = lshift(1, bits + 1)
    local pal = {}
    for i = 0, size - 1 do
        local r, g, b = data:byte(pos + i * 3, pos + i * 3 + 2)
        pal[i] = {r or 0, g or 0, b or 0}
    end
    return pal, pos + size * 3
end

-- returns an array of palette indexes (1-based) and how many were decoded
local function lzwDecode(data, minCode, pixelCount)
    if minCode < 2 or minCode > 8 then return nil, "bad lzw code size" end
    local out = table.create(pixelCount, 0)
    local outN = 0
    local clear = lshift(1, minCode)
    local eoi = clear + 1
    local codeSize = minCode + 1
    local nextCode = eoi + 1
    local prefix, suffix, stack = {}, {}, {}
    local prev
    local bitBuf, bitCount, pos, len = 0, 0, 1, #data

    while outN < pixelCount do
        while bitCount < codeSize do
            if pos > len then return out, outN end
            bitBuf = bor(bitBuf, lshift(data:byte(pos), bitCount))
            bitCount += 8
            pos += 1
        end
        local code = band(bitBuf, lshift(1, codeSize) - 1)
        bitBuf = rshift(bitBuf, codeSize)
        bitCount -= codeSize

        if code == clear then
            codeSize = minCode + 1
            nextCode = eoi + 1
            prev = nil
        elseif code == eoi then
            break
        elseif prev == nil then
            if code >= clear then return nil, "corrupt gif data" end
            outN += 1
            out[outN] = code
            prev = code
        else
            if code > nextCode then return nil, "corrupt gif data" end
            local isK = (code == nextCode)
            local cur = isK and prev or code
            local n = 0
            while cur >= clear do
                n += 1
                stack[n] = suffix[cur]
                cur = prefix[cur]
            end
            local root = cur
            outN += 1
            out[outN] = root
            for i = n, 1, -1 do
                outN += 1
                out[outN] = stack[i]
            end
            if isK then
                outN += 1
                out[outN] = root
            end
            if nextCode < 4096 then
                prefix[nextCode] = prev
                suffix[nextCode] = root
                nextCode += 1
                if nextCode == lshift(1, codeSize) and codeSize < 12 then codeSize += 1 end
            end
            prev = code
        end
    end
    return out, outN
end

local function interlaceOrder(h)
    local order = {}
    for _, pass in ipairs({{0, 8}, {4, 8}, {2, 4}, {1, 2}}) do
        for r = pass[1], h - 1, pass[2] do order[#order + 1] = r end
    end
    return order
end

-- returns {{png = "<bytes>", delay = seconds}, ...} or nil, reason
local function decodeGif(data, cfg)
    if data:sub(1, 3) ~= "GIF" then return nil, "not a gif file" end
    local w, h = rd16(data, 7), rd16(data, 9)
    if w == 0 or h == 0 then return nil, "empty gif" end
    if w > cfg.GifMaxSize or h > cfg.GifMaxSize then
        return nil, ("gif is %dx%d, bigger than GifMaxSize (%d). shrink it first (ezgif.com/resize)")
            :format(w, h, cfg.GifMaxSize)
    end

    local flags = data:byte(11)
    local pos = 14
    local gct
    if band(flags, 0x80) ~= 0 then
        gct, pos = readPalette(data, pos, band(flags, 7))
    end

    local stride = 1 + w * 4
    local canvas = table.create(h * stride, 0)
    local frames = {}
    local gce
    local len = #data

    while pos <= len do
        local block = data:byte(pos)
        if block == 0x3B then
            break
        elseif block == 0x21 then
            if data:byte(pos + 1) == 0xF9 then
                local pk = data:byte(pos + 3)
                gce = {
                    disposal = band(rshift(pk, 2), 7),
                    transparent = (band(pk, 1) == 1) and data:byte(pos + 6) or nil,
                    delay = rd16(data, pos + 4) / 100,
                }
            end
            pos += 2
            while true do
                local n = data:byte(pos)
                if not n then break end
                pos += 1 + n
                if n == 0 then break end
            end
        elseif block == 0x2C then
            local ix, iy = rd16(data, pos + 1), rd16(data, pos + 3)
            local iw, ih = rd16(data, pos + 5), rd16(data, pos + 7)
            local ipk = data:byte(pos + 9)
            pos += 10
            local palette = gct
            if band(ipk, 0x80) ~= 0 then
                palette, pos = readPalette(data, pos, band(ipk, 7))
            end
            local interlaced = band(ipk, 0x40) ~= 0
            local minCode = data:byte(pos)
            pos += 1
            local chunks = {}
            while true do
                local n = data:byte(pos)
                pos += 1
                if not n or n == 0 then break end
                chunks[#chunks + 1] = data:sub(pos, pos + n - 1)
                pos += n
            end

            local idx, why = lzwDecode(table.concat(chunks), minCode or 0, iw * ih)
            if not idx then return nil, why end

            local g = gce or {disposal = 0, delay = 0.1}
            gce = nil
            local saved
            if g.disposal == 3 then saved = table.clone(canvas) end
            local transparent = g.transparent
            local order = interlaced and interlaceOrder(ih) or nil

            for row = 0, ih - 1 do
                local y = iy + (order and order[row + 1] or row)
                if y < h then
                    for col = 0, iw - 1 do
                        local x = ix + col
                        if x < w then
                            local c = idx[row * iw + col + 1]
                            if c ~= transparent then
                                local color = palette and palette[c]
                                if color then
                                    local p = y * stride + 2 + x * 4
                                    canvas[p] = color[1]
                                    canvas[p + 1] = color[2]
                                    canvas[p + 2] = color[3]
                                    canvas[p + 3] = 255
                                end
                            end
                        end
                    end
                end
            end

            local delay = g.delay
            if delay < 0.02 then delay = 0.1 end -- browsers treat tiny delays as 0.1s
            frames[#frames + 1] = {png = encodePNG(w, h, canvas), delay = delay}

            -- prepare the canvas for the next frame
            if g.disposal == 2 then
                for y = iy, math.min(iy + ih - 1, h - 1) do
                    for x = ix, math.min(ix + iw - 1, w - 1) do
                        local p = y * stride + 2 + x * 4
                        canvas[p], canvas[p + 1], canvas[p + 2], canvas[p + 3] = 0, 0, 0, 0
                    end
                end
            elseif g.disposal == 3 and saved then
                canvas = saved
            end

            task.wait() -- keep the game responsive while decoding
            if #frames >= cfg.GifMaxFrames then
                warn(("%sgif has more than %d frames, the rest were cut off (raise GifMaxFrames)")
                    :format(TAG, cfg.GifMaxFrames))
                break
            end
        else
            pos += 1 -- unknown byte, skip
        end
    end

    if #frames == 0 then return nil, "gif had no frames" end
    return frames
end

-- decodes a gif, saves each frame as a png, returns asset array + file paths
local function convertGif(body, prefix, cfg, use)
    local ok, frames, err = pcall(decodeGif, body, cfg)
    if not ok then
        err = frames
        frames = nil
    end
    if not frames then
        warn(TAG .. "couldn't turn that gif into frames: " .. tostring(err))
        return nil
    end
    local assets, paths, totalDelay = {}, {}, 0
    for i, f in ipairs(frames) do
        local p = ("%s_g%03d.png"):format(prefix, i)
        pcall(writefile, p, f.png)
        local a = use(p)
        if not a then
            warn(TAG .. "getcustomasset failed for gif frame " .. p)
            return nil
        end
        assets[i] = a
        paths[#paths + 1] = p
        totalDelay += f.delay
    end
    local avg = totalDelay / #frames
    local manifest = prefix .. "_gif.txt"
    pcall(writefile, manifest, ("%d,%.3f"):format(#frames, avg))
    paths[#paths + 1] = manifest
    info(cfg, ("gif split into %d frames. its own speed is ~%.3fs per frame, set your frame switch speed to about that")
        :format(#frames, avg))
    return assets, paths
end

-- pixel size of images we downloaded, keyed by the asset string (only filled when SliceGlitch is on).
-- exact slicing needs it. png/jpg sizes are read straight from the file header
local ASSET_DIMS = {}

local function imageSize(data)
    if type(data) ~= "string" then return nil end
    if data:sub(1, 8) == "\137PNG\r\n\26\n" and #data >= 24 then
        local a, b, c, d, e, f, g, h = data:byte(17, 24)
        return {((a * 256 + b) * 256 + c) * 256 + d, ((e * 256 + f) * 256 + g) * 256 + h}
    end
    if data:sub(1, 2) == "\255\216" then -- jpeg: walk the markers until the start-of-frame one
        local pos = 3
        local len = #data
        while pos + 9 <= len do
            if data:byte(pos) ~= 0xFF then
                pos += 1
            else
                local m = data:byte(pos + 1)
                if m == 0xFF then
                    pos += 1
                elseif m == 0xD8 or m == 0x01 or (m >= 0xD0 and m <= 0xD7) then
                    pos += 2
                else
                    if m >= 0xC0 and m <= 0xCF and m ~= 0xC4 and m ~= 0xC8 and m ~= 0xCC then
                        local h = data:byte(pos + 5) * 256 + data:byte(pos + 6)
                        local w = data:byte(pos + 7) * 256 + data:byte(pos + 8)
                        return {w, h}
                    end
                    pos += 2 + data:byte(pos + 2) * 256 + data:byte(pos + 3)
                end
            end
        end
    end
    return nil
end

local function dimsFromFiles(files)
    if not (files and readfile) then return nil end
    for _, p in ipairs(files) do
        if p:match("%.png$") or p:match("%.jpg$") then
            local ok, data = pcall(readfile, p)
            if ok then
                local dims = imageSize(data)
                if dims then return dims end
            end
        end
    end
    return nil
end

-- --- ZIP READER ---
-- a zip of pngs: skin.zip holding idle1.png, idle2.png ... walk1.png, walk2.png ... (any capitals, any folders).
-- inflate is the standard deflate decompressor (a port of the classic "puff" algorithm)
local LBASE = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
local LEXT = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
local DBASE = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
local DEXT = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}
local CLORDER = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}

-- builds a huffman table from code lengths lengths[1..n]
local function huffman(lengths, n)
    local count = {}
    for l = 0, 15 do count[l] = 0 end
    for i = 1, n do count[lengths[i]] += 1 end
    local offs = {[1] = 0}
    for l = 1, 14 do offs[l + 1] = offs[l] + count[l] end
    local symbol = {}
    for i = 1, n do
        local l = lengths[i]
        if l ~= 0 then
            symbol[offs[l]] = i - 1
            offs[l] += 1
        end
    end
    return {count = count, symbol = symbol}
end

local FIXED_LIT, FIXED_DIST
local function fixedTables()
    if not FIXED_LIT then
        local l = {}
        for i = 1, 144 do l[i] = 8 end
        for i = 145, 256 do l[i] = 9 end
        for i = 257, 280 do l[i] = 7 end
        for i = 281, 288 do l[i] = 8 end
        FIXED_LIT = huffman(l, 288)
        local d = {}
        for i = 1, 30 do d[i] = 5 end
        FIXED_DIST = huffman(d, 30)
    end
    return FIXED_LIT, FIXED_DIST
end

-- decompresses raw deflate data that starts at data:byte(pos). returns the bytes as a string
local function inflate(data, pos)
    local len = #data
    local bitbuf, bitcnt = 0, 0
    local out, n = {}, 0
    local lastYield = 0

    local function bits(need)
        local val = bitbuf
        while bitcnt < need do
            if pos > len then error("the zip data ended early") end
            val = bor(val, lshift(data:byte(pos), bitcnt))
            pos += 1
            bitcnt += 8
        end
        bitbuf = rshift(val, need)
        bitcnt -= need
        return band(val, lshift(1, need) - 1)
    end

    local function decode(h)
        local count, symbol = h.count, h.symbol
        local code, first, index = 0, 0, 0
        for l = 1, 15 do
            if bitcnt == 0 then
                if pos > len then error("the zip data ended early") end
                bitbuf = data:byte(pos)
                pos += 1
                bitcnt = 8
            end
            code = bor(code, band(bitbuf, 1))
            bitbuf = rshift(bitbuf, 1)
            bitcnt -= 1
            local c = count[l]
            if code - c < first then
                local sym = symbol[index + (code - first)]
                if sym == nil then error("bad huffman code in the zip") end
                return sym
            end
            index += c
            first = lshift(first + c, 1)
            code = lshift(code, 1)
        end
        error("bad huffman code in the zip")
    end

    local function codes(lit, dist)
        while true do
            local sym = decode(lit)
            if sym < 256 then
                n += 1
                out[n] = sym
            elseif sym == 256 then
                return
            else
                sym -= 257
                if sym >= 29 then error("bad length code in the zip") end
                local l = LBASE[sym + 1] + bits(LEXT[sym + 1])
                local ds = decode(dist)
                if ds >= 30 then error("bad distance code in the zip") end
                local d = DBASE[ds + 1] + bits(DEXT[ds + 1])
                if d > n then error("bad distance in the zip") end
                for _ = 1, l do
                    n += 1
                    out[n] = out[n - d]
                end
            end
            if n - lastYield > 60000 then
                lastYield = n
                task.wait() -- keep the game responsive while a big zip opens
            end
        end
    end

    local function stored()
        bitbuf, bitcnt = 0, 0
        if pos + 3 > len then error("the zip data ended early") end
        local a, b, c, d = data:byte(pos, pos + 3)
        local l = a + b * 256
        if l ~= bxor(c + d * 256, 0xFFFF) then error("bad stored block in the zip") end
        pos += 4
        if pos + l - 1 > len then error("the zip data ended early") end
        local i = pos
        while i < pos + l do
            local j = math.min(i + 3999, pos + l - 1)
            local chunk = {data:byte(i, j)}
            for k = 1, #chunk do
                n += 1
                out[n] = chunk[k]
            end
            i = j + 1
        end
        pos += l
    end

    local function dynamic()
        local nlen = bits(5) + 257
        local ndist = bits(5) + 1
        local ncode = bits(4) + 4
        if nlen > 286 or ndist > 30 then error("bad block sizes in the zip") end
        local lengths = {}
        for i = 1, 19 do lengths[i] = 0 end
        for i = 1, ncode do lengths[CLORDER[i] + 1] = bits(3) end
        local lencode = huffman(lengths, 19)
        local ll, idx = {}, 0
        while idx < nlen + ndist do
            local sym = decode(lencode)
            if sym < 16 then
                idx += 1
                ll[idx] = sym
            else
                local prev, rep = 0, 0
                if sym == 16 then
                    if idx == 0 then error("bad repeat in the zip") end
                    prev = ll[idx]
                    rep = 3 + bits(2)
                elseif sym == 17 then
                    rep = 3 + bits(3)
                else
                    rep = 11 + bits(7)
                end
                if idx + rep > nlen + ndist then error("bad repeat in the zip") end
                for _ = 1, rep do
                    idx += 1
                    ll[idx] = prev
                end
            end
        end
        local litLens, distLens = {}, {}
        for i = 1, nlen do litLens[i] = ll[i] end
        for i = 1, ndist do distLens[i] = ll[nlen + i] end
        codes(huffman(litLens, nlen), huffman(distLens, ndist))
    end

    local last
    repeat
        last = bits(1)
        local typ = bits(2)
        if typ == 0 then
            stored()
        elseif typ == 1 then
            local lit, dist = fixedTables()
            codes(lit, dist)
        elseif typ == 2 then
            dynamic()
        else
            error("bad block type in the zip")
        end
    until last == 1

    local parts, i = {}, 1
    while i <= n do
        local j = math.min(i + 3999, n)
        parts[#parts + 1] = string.char(unpack(out, i, j))
        i = j + 1
    end
    return table.concat(parts)
end

local function u16le(str, p)
    local a, b = str:byte(p, p + 1)
    return (a or 0) + (b or 0) * 256
end
local function u32le(str, p)
    local a, b, c, d = str:byte(p, p + 3)
    return (a or 0) + (b or 0) * 256 + (c or 0) * 65536 + (d or 0) * 16777216
end

-- which files of a zip we care about: pngs / jpgs (not folders, hidden files or the mac junk folder)
local function zipWanted(name)
    local n = (name:gsub("\\", "/")):lower()
    if n:find("__macosx", 1, true) then return false end
    local file = n:match("([^/]+)$")
    if not file or file:sub(1, 1) == "." then return false end
    return file:match("%.png$") ~= nil or file:match("%.jpe?g$") ~= nil
end

-- opens a zip: returns a list of {name = "folder/file.png", data = "<bytes>"} for the files wanted(name) accepts
local function readZip(body, wanted)
    local size = #body
    local eocd
    for p = size - 21, math.max(1, size - 65557), -1 do
        if body:sub(p, p + 3) == "PK\5\6" then
            eocd = p
            break
        end
    end
    if not eocd then error("not a valid zip (its file list wasn't found)") end
    local total = u16le(body, eocd + 10)
    local p = u32le(body, eocd + 16) + 1
    local files = {}
    for _ = 1, total do
        if body:sub(p, p + 3) ~= "PK\1\2" then break end
        local flags = u16le(body, p + 8)
        local method = u16le(body, p + 10)
        local csize = u32le(body, p + 20)
        local usize = u32le(body, p + 24)
        local nlen, elen, clen = u16le(body, p + 28), u16le(body, p + 30), u16le(body, p + 32)
        local lpos = u32le(body, p + 42) + 1
        local name = body:sub(p + 46, p + 45 + nlen)
        p = p + 46 + nlen + elen + clen
        if usize > 0 and name:sub(-1) ~= "/" and wanted(name) then
            if band(flags, 1) ~= 0 then
                warn(TAG .. "skipped '" .. name .. "' (it is password protected)")
            elseif method ~= 0 and method ~= 8 then
                warn(TAG .. "skipped '" .. name .. "' (unsupported zip compression)")
            else
                if body:sub(lpos, lpos + 3) ~= "PK\3\4" then error("a zip entry is damaged") end
                local dstart = lpos + 30 + u16le(body, lpos + 26) + u16le(body, lpos + 28)
                local data
                if method == 0 then
                    data = body:sub(dstart, dstart + csize - 1)
                else
                    data = inflate(body, dstart)
                end
                if #data ~= usize then error("a zip entry came out the wrong size: " .. name) end
                files[#files + 1] = {name = name, data = data}
            end
        end
    end
    return files
end

-- natural order: idle2 comes before idle10, and capitals don't matter
local function natLess(a, b)
    a, b = a:lower(), b:lower()
    local i, j = 1, 1
    while i <= #a and j <= #b do
        local da, db = a:match("^%d+", i), b:match("^%d+", j)
        if da and db then
            local na, nb = tonumber(da), tonumber(db)
            if na ~= nb then return na < nb end
            i += #da
            j += #db
        else
            local ca, cb = a:sub(i, i), b:sub(j, j)
            if ca ~= cb then return ca < cb end
            i += 1
            j += 1
        end
    end
    return (#a - i) < (#b - j)
end

-- which frame a file in the zip is: idle1.png / IDLE_2.PNG / Walk 3.png -> ("idle", 1) ... ; a bare number inside
-- an Idle or Walk folder (Walk/3.png) counts too. a name with no number is frame 1
local function zipRole(path)
    local parts = {}
    for part in (path:gsub("\\", "/")):gmatch("[^/]+") do parts[#parts + 1] = part end
    local file = parts[#parts]
    if not file then return nil end
    local stem = (file:gsub("%.%w+$", "")):lower()
    local word, digits = stem:match("^(%a+)[%s_%-]*(%d*)$")
    if word == "idle" or word == "walk" then return word, tonumber(digits) or 1 end
    local d = stem:match("^(%d+)$")
    local dir = parts[#parts - 1]
    if d and dir then
        dir = dir:lower()
        if dir == "idle" or dir == "walk" then return dir, tonumber(d) end
    end
    return nil
end

-- opens a zip of pngs, saves every png and returns the usual ARRAY of assets (all pngs in natural name order)
-- with .roles = {idle = {...}, walk = {...}} added (numbered by their file names), plus the files it wrote
local function extractZip(body, prefix, cfg, use)
    local ok, files = pcall(readZip, body, zipWanted)
    if not ok then
        warn(TAG .. "couldn't open that zip: " .. tostring(files))
        return nil
    end
    if #files == 0 then
        warn(TAG .. "that zip has no png/jpg files in it")
        return nil
    end
    table.sort(files, function(x, y) return natLess(x.name, y.name) end)

    local assets, paths, manifest = {}, {}, {}
    local roleLists = {idle = {}, walk = {}}
    for i, f in ipairs(files) do
        local ext = sniff(f.data)
        if ext == "png" or ext == "jpg" then
            local p = ("%s_z%03d.%s"):format(prefix, i, ext)
            pcall(writefile, p, f.data)
            local a = use(p)
            if a then
                assets[#assets + 1] = a
                paths[#paths + 1] = p
                manifest[#manifest + 1] = "all\t" .. p
                if cfg.SliceGlitch then ASSET_DIMS[a] = imageSize(f.data) end
                local role, num = zipRole(f.name)
                if role then table.insert(roleLists[role], {num = num, name = f.name, asset = a, path = p}) end
            else
                warn(TAG .. "getcustomasset failed for a frame of the zip: " .. f.name)
            end
        end
    end
    if #assets == 0 then
        warn(TAG .. "none of the images in that zip could be used")
        return nil
    end

    assets.roles = {idle = {}, walk = {}}
    for role, list in pairs(roleLists) do
        table.sort(list, function(x, y)
            if x.num ~= y.num then return x.num < y.num end
            return natLess(x.name, y.name)
        end)
        local lastNum
        for _, e in ipairs(list) do
            if e.num == lastNum then
                warn(("%s'%s' has the same %s frame number as another file in the zip, skipping it"):format(TAG, e.name, role))
            else
                lastNum = e.num
                assets.roles[role][#assets.roles[role] + 1] = e.asset
                manifest[#manifest + 1] = role .. "\t" .. e.path
            end
        end
    end
    local manifestPath = prefix .. "_zip.txt"
    pcall(writefile, manifestPath, table.concat(manifest, "\n"))
    paths[#paths + 1] = manifestPath
    info(cfg, ("zip opened: %d image(s), %d idle frame(s), %d walk frame(s)"):format(#assets, #assets.roles.idle, #assets.roles.walk))
    if #assets.roles.idle == 0 and #assets.roles.walk == 0 then
        warn(TAG .. "no file in that zip is named idle1.png / walk1.png style, so it can only be used where every image is wanted (orbs, scares)")
    end
    return assets, paths
end

-- a zip we already opened on an earlier run
local function loadZipCache(manifestPath, cfg, use)
    local okr, txt = pcall(readfile, manifestPath)
    if not okr or type(txt) ~= "string" then return nil end
    local byPath, assets, paths = {}, {}, {manifestPath}
    local roles = {idle = {}, walk = {}}
    for line in txt:gmatch("[^\r\n]+") do
        local kind, p = line:match("^(%a+)\t(.+)$")
        if kind and p then
            if not byPath[p] then
                if not isfile(p) then return nil end
                local a = use(p)
                if not a then return nil end
                byPath[p] = a
                paths[#paths + 1] = p
                if cfg.SliceGlitch then
                    local okf, data = pcall(readfile, p)
                    if okf then ASSET_DIMS[a] = imageSize(data) end
                end
            end
            if kind == "all" then
                assets[#assets + 1] = byPath[p]
            elseif roles[kind] then
                roles[kind][#roles[kind] + 1] = byPath[p]
            end
        end
    end
    if #assets == 0 then return nil end
    assets.roles = roles
    info(cfg, ("zip (cached): %d image(s), %d idle frame(s), %d walk frame(s)"):format(#assets, #roles.idle, #roles.walk))
    return assets, paths
end

local function findCached(prefix, kind)
    local list = (kind == "audio") and AUDIO_EXTS or IMAGE_EXTS
    for _, e in ipairs(list) do
        local p = prefix .. "." .. e
        if isfile(p) then return p end
    end
    return nil
end

-- one download with retries. returns body, ext  (or nil, reason)
local function download(url, kind, cfg, isAlt)
    local attempts = math.max(math.floor(cfg.DownloadRetries), 0) + 1
    local reason = "unknown error"
    for attempt = 1, attempts do
        local ok, res = pcall(request, {Url = url, Method = "GET", Headers = HEADERS})
        if ok and type(res) == "table" then
            local body = res.Body
            local status = tostring(res.StatusCode or "?")
            if body and #body > 0 then
                local ext = sniff(body)
                if ext and good(kind, ext, cfg) then return body, ext end
                if ext then
                    -- wrong format. for wiki links, ask the cdn for the original png first
                    if not isAlt then
                        local alt = wikiOriginal(url)
                        if alt then
                            local b2, e2 = download(alt, kind, cfg, true)
                            if b2 and good(kind, e2, cfg) then return b2, e2 end
                        end
                    end
                    -- still not a supported format: use it anyway if allowed
                    if tolerated(kind, ext, cfg) then return body, ext end
                    -- permanent problem, retrying won't help
                    return nil, ("link served a %s file, roblox can't use that here. use png/jpg (or mp3/ogg)")
                        :format(ext:upper())
                end
                local preview = (body:sub(1, 40):gsub("%c+", " "))
                reason = ("HTTP %s, %d bytes, not an image/audio file, starts with %q")
                    :format(status, #body, preview)
                local code = tonumber(res.StatusCode)
                -- client errors (403/404...) won't fix themselves, except 429
                if code and code >= 400 and code < 500 and code ~= 429 then break end
            else
                reason = ("HTTP %s, empty body"):format(status)
            end
        else
            reason = "request error: " .. tostring(res)
        end
        if attempt < attempts then task.wait(0.4 * attempt) end
    end
    return nil, reason
end

-- downloads (or reuses cached) a link. returns an ARRAY of getcustomasset strings
-- (one entry normally, many for a gif) plus an array of the files used. nil on failure
local function fetch(url, kind, cfg)
    if not (request and writefile and isfile and customAsset) then
        warn(TAG .. "executor can't download links (missing request/writefile/getcustomasset): " .. url)
        return nil
    end
    if makefolder and isfolder and not isfolder(CACHE_DIR) then pcall(makefolder, CACHE_DIR) end
    local base = (isfolder and isfolder(CACHE_DIR)) and (CACHE_DIR .. "/") or ""

    local safeName = tostring(cfg.SkinName or "Skin"):gsub("[^%w_%-]", "_")
    -- the url hash is in the filename, so changing a link automatically downloads fresh
    local prefix = ("%s%s_%s"):format(base, safeName, hash(url))

    local function use(path)
        local ok, asset = pcall(customAsset, path)
        if ok and asset then return asset end
        return nil
    end

    -- a file from your executor's workspace folder: a png/jpg is used as it is (it is never deleted), a zip is opened
    if not isLink(url) then
        local okr, data = pcall(readfile, url)
        if not okr or type(data) ~= "string" or #data == 0 then
            warn(TAG .. "couldn't read the file: " .. url)
            return nil
        end
        local ext = sniff(data)
        if ext == "zip" and kind == "image" then return extractZip(data, prefix, cfg, use) end
        if ext and ext ~= "zip" and good(kind, ext, cfg) then
            local a = use(url)
            if a then return {a}, {} end
        end
        warn(TAG .. "that file isn't a png/jpg/zip (or mp3/ogg for sounds): " .. url)
        return nil
    end

    if not cfg.ForceRedownload then
        -- a zip we already opened on an earlier run?
        local zipManifest = prefix .. "_zip.txt"
        if kind == "image" and readfile and isfile(zipManifest) then
            local za, zp = loadZipCache(zipManifest, cfg, use)
            if za then return za, zp end
        end

        -- a gif we already split into png frames on an earlier run?
        local manifest = prefix .. "_gif.txt"
        if kind == "image" and readfile and isfile(manifest) then
            local okr, txt = pcall(readfile, manifest)
            local count, avg = tostring(okr and txt or ""):match("^(%d+),([%d%.]+)")
            count = tonumber(count)
            if count and count > 0 then
                local assets, paths = {}, {manifest}
                for i = 1, count do
                    local p = ("%s_g%03d.png"):format(prefix, i)
                    local a = isfile(p) and use(p) or nil
                    if not a then assets = nil break end
                    assets[i] = a
                    paths[#paths + 1] = p
                end
                if assets then
                    info(cfg, ("gif (cached): %d frames, its own speed is ~%ss per frame"):format(count, avg))
                    return assets, paths
                end
            end
        end

        local cached = findCached(prefix, kind)
        if cached then
            local asset = use(cached)
            if asset then return {asset}, {cached} end
            -- cached file is corrupt: delete it and download again
            if delfile then pcall(delfile, cached) end
        end
    end

    local body, extOrReason = download(url, kind, cfg)
    if not body then
        warn(("%sdownload failed (%s): %s"):format(TAG, tostring(extOrReason), url))
        return nil
    end

    if extOrReason == "zip" and kind == "image" then
        return extractZip(body, prefix, cfg, use)
    end

    if extOrReason == "gif" and kind == "image" and cfg.ConvertGifs then
        return convertGif(body, prefix, cfg, use)
    end

    if extOrReason == "webp" or extOrReason == "gif" then
        warn(("%sthis link only gives a %s file. roblox may not draw it (blank sprite). if it's blank, re-host it as png/jpg: %s")
            :format(TAG, extOrReason:upper(), url))
    end
    local path = prefix .. "." .. extOrReason
    pcall(writefile, path, body)
    local asset = use(path)
    if not asset then
        warn(TAG .. "getcustomasset failed for " .. path)
        return nil
    end
    return {asset}, {path}
end

-- resolves every source in parallel; returns map src -> ARRAY of usable assets (or false), plus file paths
local function resolveAll(entries, cfg)
    local out, paths, pending = {}, {}, 0
    for _, e in ipairs(entries) do
        local src = e.src
        if out[src] == nil then
            out[src] = false
            if isRobloxAsset(src) then
                out[src] = {src}
            elseif isLink(src) or isLocalFile(src) then
                pending += 1
                task.spawn(function()
                    local assets, files = fetch(src, e.kind, cfg)
                    out[src] = assets or false
                    if assets and not assets.roles and cfg.SliceGlitch and e.kind == "image" then -- (zip frames got their own sizes)
                        local dims = dimsFromFiles(files) -- every frame of a gif has the same size
                        if dims then
                            for _, a in ipairs(assets) do ASSET_DIMS[a] = dims end
                        end
                    end
                    if assets and files then
                        for _, p in ipairs(files) do paths[#paths + 1] = p end
                    end
                    pending -= 1
                end)
            else
                warn(TAG .. "can't use '" .. src .. "' (use rbxassetid://..., a number, an http(s) link, or a file in your workspace folder)")
            end
        end
    end
    local deadline = os.clock() + cfg.DownloadTimeout
    while pending > 0 and os.clock() < deadline do task.wait(0.05) end
    if pending > 0 then
        warn(("%sdownloads timed out after %ds (%d unfinished). raise DownloadTimeout (big gifs take longer)"):format(
            TAG, cfg.DownloadTimeout, pending))
    end
    return out, paths
end

local function toList(v)
    if v == nil then return {} end
    if type(v) ~= "table" then return {v} end
    return v
end

-- turns a skip list like {2, 4} into a lookup set. a missing/empty list skips nothing,
-- and anything that isn't a positive number is ignored instead of erroring
local function toIndexSet(v, name)
    local set = {}
    if v == nil then return set end
    if type(v) == "number" then v = {v} end
    if type(v) ~= "table" then
        warn(TAG .. name .. " should be a list like {2, 4}, ignoring it")
        return set
    end
    for _, x in ipairs(v) do
        local n = tonumber(x)
        if n and n >= 1 then set[math.floor(n)] = true end
    end
    return set
end

-- frame clock for one frame list, like the game's per-frame StepDelay. give it how long you've been in this mode
-- and it returns: the frame number, how far through that frame you are (0..1), and how many frame switches
-- have happened. cycle = ping-pong order (1,2,3,2,1,...) so no frame shows twice in a row.
-- delays = optional seconds for each frame (missing or 0 = defaultDelay)
local function makeClock(count, cycle, defaultDelay, delays)
    local seq = {}
    if cycle and count > 2 then
        for i = 1, count do seq[#seq + 1] = i end
        for i = count - 1, 2, -1 do seq[#seq + 1] = i end
    else
        for i = 1, count do seq[i] = i end
    end
    local start, dur, total = {}, {}, 0
    for k, idx in ipairs(seq) do
        local d = type(delays) == "table" and tonumber(delays[idx]) or nil
        if not d or d <= 0 then d = defaultDelay end
        d = math.max(d, 0.01)
        start[k], dur[k] = total, d
        total += d
    end
    local n = #seq
    return function(t)
        local cycles = math.floor(t / total)
        local tt = t - cycles * total
        local k = n
        for i = 1, n do
            if tt < start[i] + dur[i] then
                k = i
                break
            end
        end
        return seq[k], math.clamp((tt - start[k]) / dur[k], 0, 1), cycles * n + (k - 1)
    end
end

-- which frame set to show: auto = walk frames while you move (like the game), idle otherwise
local function animWalkFor(mode, moving)
    if mode == "walk" then return true end
    if mode == "idle" then return false end
    if mode == "reverse" then return not moving end
    return moving
end

-- what a reactive sound can listen for
local REACTIVE_WHEN = {
    walk = true, run = true, idle = true, move = true, -- states (move = walking or running)
    start = true, stop = true, jump = true, land = true, -- one-time events
}

-- settings a phase may change while the skin is running (anything that needs setup, like the slice strips or the
-- afterimage emitters, can't change per phase)
local PHASE_LIVE = {
    "FrameMode", "FrameBounceStyle", "FrameJiggle", "FrameJiggleStrength", "FrameJiggleEase",
    "FrameJump", "FrameJumpHighestHeight", "FrameSwayAmount",
    "GlitchEffect", "GlitchStrength", "GlitchRate",
    "WobbleEffect", "WobbleStrength", "WobbleSpeed", "WobbleWhenIdle",
    "HoverBob", "HoverHeight", "HoverSpeed", "HoverOnlyWhenIdle",
    "BreathEffect", "BreathStrength", "BreathSpeed",
    "GhostPulse", "GhostPulseMin", "GhostPulseSpeed",
    "FlickerEffect", "FlickerRate", "FlickerDuration", "FlickerDepth",
    "BoilEffect", "BoilStrength", "BoilRate",
    "RainbowKeyframeColor", "RainbowSpeed",
}
local BLEND_KEYS = {"sx", "sy", "ox", "oy", "oz", "transparency", "brightness"}

local function mulColor(a, b)
    return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
end

-- the game's walk bounce + sway for one billboard. st = {y, r, lastStep, fromY, fromR}; returns hop height and sway angle.
--   style "step"      = the game's BouncePerStep: every walk step the skin rises and falls once (a half-sine) and the sway
--                       tips out and back to center, on alternating sides
--   style "alternate" = the game's BouncePerStep2: on odd walk frames the skin RISES (Sine Out) and on even frames it
--                       FALLS (Sine In), and the sway rocks from one side to the other (+S, then -S, then +S...).
--                       each move starts from wherever the skin is at that moment, exactly like a tween does
-- frames in skip (FrameSkipJump) don't hop. everything comes from the walk clock, nothing is accumulated
local function stepBounce(st, style, active, idx, p, stepNo, height, sway, skip, dt)
    if not active then
        local k = 1 - math.min(1, dt * 18) -- the walk stopped: settle back to rest
        st.y *= k
        st.r *= k
        if st.y < 0.001 then st.y = 0 end
        if math.abs(st.r) < 0.01 then st.r = 0 end
        st.lastStep = nil
        return st.y, st.r
    end
    local skipped = skip ~= nil and skip[idx] == true
    if style == "alternate" then
        if stepNo ~= st.lastStep then
            st.lastStep = stepNo
            st.fromY, st.fromR = st.y, st.r
        end
        local odd = idx % 2 == 1
        local e = odd and math.sin(p * math.pi / 2) or (1 - math.cos(p * math.pi / 2)) -- Sine Out / Sine In
        local toY = (odd and not skipped) and height or 0
        st.y = st.fromY + (toY - st.fromY) * e
        if sway ~= 0 then
            local toR = odd and sway or -sway
            st.r = st.fromR + (toR - st.fromR) * e
        end
    else
        st.y = skipped and 0 or height * math.sin(math.pi * p)
        if sway ~= 0 then st.r = sway * math.sin(math.pi * p) * ((stepNo % 2 == 0) and 1 or -1) end
    end
    return st.y, st.r
end

-- removes the current skin (if any)
function Brain.Stop()
    if env.__SkinBrainCleanup then
        pcall(env.__SkinBrainCleanup)
        env.__SkinBrainCleanup = nil
    end
end

-- --- RUN ---
function Brain.Run(userCfg)
    Brain.Stop() -- re-execute guard

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
    -- SkinZip: a zip of pngs named idle1.png, walk1.png ... gives BOTH lists. its frames come after your own lists
    for _, z in ipairs(collect(cfg.SkinZip, "image")) do
        idleSrc[#idleSrc + 1] = z
        walkSrc[#walkSrc + 1] = z
    end
    -- scare event: the main scare (ScareImage / ScareSound ...) plus every entry in ScareVariants. a variant can override
    -- any Scare setting (Image, Sound, Volume, SizeX, SizeY, StudsOffsetX/Y/Z, Brightness, Shake, RemoveBear,
    -- RemoveAfterimage ...) and whatever it leaves out comes from the main scare. only downloaded when the event is on
    local scareSpecs = {}
    if cfg.ScareEvent then
        local function addScare(over, weight, label)
            local sp = {
                label = label, weight = math.max(weight, 0),
                Image = cfg.ScareImage, Sound = cfg.ScareSound, ImageFrameSpeed = 0.1,
                Volume = cfg.ScareVolume, SizeX = cfg.ScareSizeX, SizeY = cfg.ScareSizeY,
                StudsOffsetX = cfg.ScareStudsOffsetX, StudsOffsetY = cfg.ScareStudsOffsetY, StudsOffsetZ = cfg.ScareStudsOffsetZ,
                Brightness = cfg.ScareBrightness, Shake = cfg.ScareShake,
                ZoomFrom = 1, ZoomTime = 0.25, FadeOut = 0, Blink = 0,
                RemoveBear = cfg.ScareRemoveBear, RemoveAfterimage = cfg.ScareRemoveAfterimage,
            }
            for k, v in pairs(over) do
                if k ~= "Weight" and k ~= "Name" then sp[k] = v end
            end
            sp.imgSrc = collect(sp.Image, "image")
            sp.sndSrc = collect(sp.Sound, "audio")
            scareSpecs[#scareSpecs + 1] = sp
        end
        if cfg.ScareMainWeight > 0 then addScare({}, cfg.ScareMainWeight, "main") end
        if type(cfg.ScareVariants) == "table" then
            for i, v in ipairs(cfg.ScareVariants) do
                if type(v) == "table" and v.Enabled ~= false then -- Enabled = false switches a variant off
                    addScare(v, tonumber(v.Weight) or 1, tostring(v.Name or ("variant " .. i)))
                end
            end
        end
    end

    -- orbs: one spec per orb. settings come from OrbOrbit, and each entry in Orbs can override any of them
    local orbCfg = type(cfg.OrbOrbit) == "table" and cfg.OrbOrbit or nil
    local orbSpecs = {}
    if orbCfg and orbCfg.Enabled then
        local shared = {
            Type = "Ball",                           -- Ball | Fire | Smoke | Sparkles | Image
            Color = Color3.fromRGB(255, 120, 60),
            Size = 2,                                -- studs
            Distance = 6,                            -- studs away from you
            Height = 0,                              -- studs above your center (0 = your center height)
            Speed = 0.5,                             -- orbits per second (negative = the other way)
            Transparency = 0,
            Tilt = 0,                                -- degrees, tips the orbit ring (90 = a vertical ring)
            Bob = 0,                                 -- studs of up/down bobbing
            BobSpeed = 1,
            Pattern = "circle",                      -- circle | figure8 | spiral | flower | snake
            PatternPetals = 3,                       -- flower only: petal count
            SnakeSpacing = 0.3,                      -- snake only: seconds between each orb along your path
            Wobble = 0,                              -- degrees the whole ring rocks back and forth (the game's LordOrbs rock 1 degree)
            WobbleSpeed = 0.0625,                    -- rocks per second (0.0625 = once every 16 seconds, like the game)
            FieldRadius = 3,                         -- invisible magnetic field: studs from your center that orbs never enter (0 = off)
            FieldHeight = 4,                         -- how far up/down from your center the field reaches
            ImageFrameSpeed = 0.1,                   -- seconds per frame for gif/multi-frame image orbs
        }
        -- Preset = "lord": the game's own LordOrbs numbers (ring radius 5, one orbit every 6 seconds, rocks +-1 degree
        -- once every 16 seconds). anything you set yourself still wins
        if tostring(orbCfg.Preset or ""):lower() == "lord" then
            shared.Distance, shared.Speed, shared.Wobble, shared.WobbleSpeed = 5, 1 / 6, 1, 0.0625
        end
        for k, v in pairs(orbCfg) do
            if k ~= "Enabled" and k ~= "Orbs" and k ~= "Count" and k ~= "Preset" then shared[k] = v end
        end
        local entries = (type(orbCfg.Orbs) == "table" and #orbCfg.Orbs > 0) and orbCfg.Orbs or nil
        local n = entries and #entries or math.max(math.floor(orbCfg.Count or 1), 1)
        for i = 1, n do
            local spec = {}
            for k, v in pairs(shared) do spec[k] = v end
            if entries then
                for k, v in pairs(entries[i]) do spec[k] = v end
            end
            local entry = entries and entries[i] or {}
            spec.fireColor = entry.FireColor or entry.Color or shared.FireColor
            spec.Type = tostring(spec.Type):lower()
            spec.Pattern = tostring(spec.Pattern or "circle"):lower()
            spec.index = i
            spec.Color = fixColor(spec.Color, cfg)
            if spec.SecondaryColor then spec.SecondaryColor = fixColor(spec.SecondaryColor, cfg) end
            if spec.ImageColor then spec.ImageColor = fixColor(spec.ImageColor, cfg) end
            spec.phase = spec.Phase and math.rad(spec.Phase) or ((i - 1) / n * math.pi * 2)
            if spec.Type == "image" then spec.imageSrc = collect(spec.Image, "image") end
            if spec.Texture then spec.textureSrc = collect(spec.Texture, "image") end
            orbSpecs[#orbSpecs + 1] = spec
        end
    end

    -- phases: every phase is your main settings plus whatever that phase changes. its sprites are downloaded too.
    -- without PhaseSystem there is just one phase: your main skin
    local phaseSpecs = {}
    if cfg.PhaseSystem and type(cfg.Phases) == "table" then
        for i, p in ipairs(cfg.Phases) do
            if type(p) == "table" and p.Enabled ~= false then
                local sp = {}
                for k, v in pairs(p) do sp[k] = v end
                sp.name = tostring(p.Name or ("phase " .. i))
                -- a phase's own sprites: its Idle / Walk lists and/or a Zip (a zip of idle1.png, walk1.png ...).
                -- a phase that sets none of them keeps your main sprites
                local zips = (p.Zip ~= nil) and collect(p.Zip, "image") or nil
                local function own(list)
                    if p[list] == nil and not zips then return nil end
                    local srcs = (p[list] ~= nil) and collect(p[list], "image") or {}
                    for _, z in ipairs(zips or {}) do srcs[#srcs + 1] = z end
                    return srcs
                end
                sp.idleSrc = own("Idle") or idleSrc
                sp.walkSrc = own("Walk") or walkSrc
                phaseSpecs[#phaseSpecs + 1] = sp
            end
        end
        if #phaseSpecs == 0 then warn(TAG .. "PhaseSystem is on but Phases has no usable entries, using your main skin only") end
    end
    if #phaseSpecs == 0 then
        phaseSpecs[1] = {name = "main", idleSrc = idleSrc, walkSrc = walkSrc}
    end

    -- phase audio: ThemeSound, ThemeSound2, VoiceLines, StompSound and ReactiveSounds can each be changed per phase.
    -- a phase that doesn't set one uses the main one (the very same table, so it simply keeps playing through the
    -- change). a phase can set only the settings it wants to change, or turn one off (ThemeSound = {Id = ""},
    -- VoiceLines = {Enabled = false}). only the sounds of enabled things are downloaded
    local function mergeCfg(base, over)
        if type(over) ~= "table" or over == base then return base end -- (a phase that points at the main table just shares it)
        local m = {}
        if type(base) == "table" then
            for k, v in pairs(base) do m[k] = v end
        end
        for k, v in pairs(over) do m[k] = v end
        return m
    end
    local themeRecs, voiceRecs, stompRecs, reactiveRecs = {}, {}, {}, {}
    local function themeRec(tc)
        if type(tc) ~= "table" then return nil end
        if not themeRecs[tc] then
            local src = normalize(tc.Id)
            themeRecs[tc] = {cfg = tc, src = src}
            if src then entries[#entries + 1] = {src = src, kind = "audio"} end
        end
        return themeRecs[tc]
    end
    local function voiceRec(vc)
        if type(vc) ~= "table" or not vc.Enabled then return nil end
        if not voiceRecs[vc] then voiceRecs[vc] = {cfg = vc, src = collect(vc.Sounds, "audio")} end
        return voiceRecs[vc]
    end
    local function stompRec(sc)
        if type(sc) ~= "table" or not sc.Enabled then return nil end
        if not stompRecs[sc] then stompRecs[sc] = {cfg = sc, src = collect(sc.Sounds, "audio")} end
        return stompRecs[sc]
    end
    -- reactive sounds: every entry has a When trigger and one or more sounds
    local function reactiveRec(rc)
        if type(rc) ~= "table" or not rc.Enabled or type(rc.Sounds) ~= "table" then return nil end
        if not reactiveRecs[rc] then
            local specs = {}
            for i, e in ipairs(rc.Sounds) do
                local when = type(e) == "table" and tostring(e.When or ""):lower() or ""
                if REACTIVE_WHEN[when] then
                    local spec = {}
                    for k, v in pairs(e) do spec[k] = v end
                    spec.when, spec.index = when, i
                    spec.src = collect(e.Sound, "audio")
                    specs[#specs + 1] = spec
                else
                    warn(TAG .. "ReactiveSounds entry " .. i .. " needs When = walk, run, idle, move, start, stop, jump or land, skipping it")
                end
            end
            reactiveRecs[rc] = {cfg = rc, specs = specs}
        end
        return reactiveRecs[rc]
    end
    for _, sp in ipairs(phaseSpecs) do
        sp.themeRec = themeRec(mergeCfg(cfg.ThemeSound, sp.ThemeSound))
        sp.theme2Rec = themeRec(mergeCfg(cfg.ThemeSound2, sp.ThemeSound2))
        sp.voiceRec = voiceRec(mergeCfg(cfg.VoiceLines, sp.VoiceLines))
        sp.stompRec = stompRec(mergeCfg(cfg.StompSound, sp.StompSound))
        sp.reactiveRec = reactiveRec(mergeCfg(cfg.ReactiveSounds, sp.ReactiveSounds))
    end

    -- extra billboards: independent billboards on you, each with its own frames, size, offset and mode
    local extraSpecs = {}
    if type(cfg.ExtraBillboards) == "table" then
        for i, e in ipairs(cfg.ExtraBillboards) do
            if type(e) == "table" and e.Enabled ~= false then
                local spec = {}
                for k, v in pairs(e) do spec[k] = v end
                spec.index = i
                spec.idleSrc = collect(spec.Idle, "image")
                spec.walkSrc = collect(spec.Walk, "image")
                for _, z in ipairs(collect(spec.Zip, "image")) do -- Zip = a zip of idle1.png, walk1.png ...
                    spec.idleSrc[#spec.idleSrc + 1] = z
                    spec.walkSrc[#spec.walkSrc + 1] = z
                end
                extraSpecs[#extraSpecs + 1] = spec
            end
        end
    end

    local resolved, downloadedPaths = resolveAll(entries, cfg)

    -- deletes the files this run downloaded/used (only if DeleteDownloadsOnRemove is on)
    local function wipeDownloads()
        if cfg.DeleteDownloadsOnRemove and delfile then
            for _, p in ipairs(downloadedPaths) do pcall(delfile, p) end
        end
    end

    -- role = "idle" / "walk": a zip then only gives the files named for that role. without a role every image of a zip is used
    local function frames(srcList, role)
        local out = {}
        for _, s in ipairs(srcList) do
            local r = resolved[s]
            if r then
                local list = r
                if role and r.roles then list = r.roles[role] or {} end
                for _, a in ipairs(list) do out[#out + 1] = a end
            end
        end
        return out
    end
    local mainIdle, mainWalk = frames(idleSrc, "idle"), frames(walkSrc, "walk")
    if #mainIdle == 0 and #mainWalk > 0 then mainIdle = {mainWalk[1]} end
    if #mainWalk == 0 then mainWalk = mainIdle end

    local phases, spriteSets = {}, {}
    for i, sp in ipairs(phaseSpecs) do
        local ph = {name = sp.name, spec = sp, themeRec = sp.themeRec, theme2Rec = sp.theme2Rec,
            voiceRec = sp.voiceRec, stompRec = sp.stompRec, reactiveRec = sp.reactiveRec}
        ph.idle, ph.walk = frames(sp.idleSrc, "idle"), frames(sp.walkSrc, "walk")
        if #ph.idle == 0 and #ph.walk > 0 then ph.idle = {ph.walk[1]} end
        if #ph.walk == 0 then ph.walk = ph.idle end
        if #ph.idle == 0 then ph.idle, ph.walk = mainIdle, mainWalk end
        -- what the billboard looks like in this phase (anything the phase doesn't set comes from your main settings)
        ph.view = {
            sx = tonumber(sp.sizeX) or cfg.sizeX, sy = tonumber(sp.sizeY) or cfg.sizeY,
            ox = tonumber(sp.studsOffsetX) or cfg.studsOffsetX,
            oy = tonumber(sp.studsOffsetY) or cfg.studsOffsetY,
            oz = tonumber(sp.studsOffsetZ) or cfg.studsOffsetZ,
            tint = (typeof(sp.Tint) == "Color3") and fixColor(sp.Tint, cfg) or cfg.Tint,
            transparency = math.clamp(tonumber(sp.Transparency) or cfg.Transparency, 0, 1),
            brightness = math.max(tonumber(sp.Brightness) or cfg.Brightness, 0),
        }
        phases[i] = ph
        spriteSets[#spriteSets + 1] = ph.idle
        spriteSets[#spriteSets + 1] = ph.walk
    end
    local phaseIndex = 1 -- which phase you start in (PhaseStart = its number or its Name)
    if type(cfg.PhaseStart) == "number" then
        phaseIndex = math.clamp(math.floor(cfg.PhaseStart), 1, #phases)
    elseif cfg.PhaseStart ~= nil then
        for i, ph in ipairs(phases) do
            if ph.name:lower() == tostring(cfg.PhaseStart):lower() then phaseIndex = i end
        end
    end
    local idle, walk = phases[phaseIndex].idle, phases[phaseIndex].walk
    local view = {} -- the billboard's current look: phases change these live
    for k, v in pairs(phases[phaseIndex].view) do view[k] = v end
    local applyPhase -- (assigned further down) switches to another phase
    for _, spec in ipairs(orbSpecs) do
        spec.frames = spec.imageSrc and frames(spec.imageSrc) or {}
        spec.texture = spec.textureSrc and frames(spec.textureSrc)[1] or nil
    end
    for _, spec in ipairs(extraSpecs) do
        spec.idle, spec.walk = frames(spec.idleSrc, "idle"), frames(spec.walkSrc, "walk")
        if #spec.idle == 0 and #spec.walk > 0 then spec.idle = {spec.walk[1]} end
        if #spec.walk == 0 then spec.walk = spec.idle end
    end
    for _, sp in ipairs(scareSpecs) do
        sp.images, sp.sounds = frames(sp.imgSrc), frames(sp.sndSrc) -- (a gif turns into several image frames)
    end
    for _, rec in pairs(voiceRecs) do rec.assets = frames(rec.src) end
    for _, rec in pairs(stompRecs) do rec.assets = frames(rec.src) end
    for _, rec in pairs(reactiveRecs) do
        for _, spec in ipairs(rec.specs) do spec.assets = frames(spec.src) end
    end
    info(cfg, ("loaded '%s': %d idle frame(s), %d walk frame(s)"):format(
        cfg.SkinName, #frames(idleSrc, "idle"), #frames(walkSrc, "walk")))
    if #idle == 0 then
        warn(TAG .. "no usable sprites loaded, nothing to show")
        wipeDownloads()
        return nil
    end
    if not char:IsDescendantOf(game) then
        wipeDownloads()
        return nil
    end

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
    gui.Size = UDim2.new(view.sx, 0, view.sy, 0)
    gui.StudsOffset = Vector3.new(view.ox, view.oy, view.oz)
    pcall(function() gui.Brightness = view.brightness end)
    gui.Parent = root

    -- holder frame: the shape effects (squash, wobble, hover...) move this, so the sprite and the
    -- layers behind it (shadow/outline/aura/rgb split) always move together
    local holder = Instance.new("Frame")
    holder.Name = "Holder"
    holder.AnchorPoint = Vector2.new(0.5, 1)   -- bottom edge stays put when squashing
    holder.Position = UDim2.new(0.5, 0, 1, 0)
    holder.Size = UDim2.new(1, 0, 1, 0)
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Parent = gui

    local sprite = Instance.new("ImageLabel")
    sprite.Name = "Sprite"
    sprite.Size = UDim2.new(1, 0, 1, 0)
    sprite.BackgroundTransparency = 1
    sprite.ImageColor3 = view.tint
    sprite.ImageTransparency = view.transparency
    if cfg.PixelArt then sprite.ResampleMode = Enum.ResamplerMode.Pixelated end
    sprite.ZIndex = 10
    sprite.Image = idle[1]
    sprite.Parent = holder

    -- layers behind the sprite (all optional). each one is a copy of whatever frame is showing
    local layers = {}
    local function addLayer(dx, dy, scale, color, transparency)
        transparency = math.clamp(transparency, 0, 1)
        local l = Instance.new("ImageLabel")
        l.Name = "Layer"
        l.AnchorPoint = Vector2.new(0.5, 0.5)
        l.Position = UDim2.new(0.5 + dx, 0, 0.5 + dy, 0)
        l.Size = UDim2.new(scale, 0, scale, 0)
        l.BackgroundTransparency = 1
        l.Image = idle[1]
        l.ImageColor3 = color
        l.ImageTransparency = transparency
        if cfg.PixelArt then l.ResampleMode = Enum.ResamplerMode.Pixelated end
        l.ZIndex = 1 + #layers -- later layers sit on top of earlier ones, all under the sprite
        l.Parent = holder
        layers[#layers + 1] = {gui = l, base = transparency}
    end
    if cfg.ShadowEffect then
        addLayer(cfg.ShadowOffsetX, cfg.ShadowOffsetY, 1, cfg.ShadowColor, cfg.ShadowTransparency)
    end
    if cfg.RGBSplit then
        local o = cfg.RGBSplitAmount
        addLayer(-o, 0, 1, Color3.fromRGB(255, 40, 40), 0.45)
        addLayer(o, 0, 1, Color3.fromRGB(40, 220, 255), 0.45)
    end

    -- horizontal slicing glitch (optional): the sprite is cut into strips and random strips slide left and right.
    -- the real sprite is hidden and the strips mirror its image / color / transparency every frame, so tint,
    -- rainbow, flicker and the rest still work. exact mode crops each strip out of the image itself (needs the
    -- image's pixel size, which we read from downloaded files). images given as rbxassetid have no readable
    -- size, so those fall back to clipping frames, and clipping stops working while the sprite is rotating
    local strips = {}
    local sliceMode
    local sliceMargin = cfg.SliceStrength + 0.02
    local function layoutStrips(asset)
        if sliceMode ~= "rect" then return end
        local dims = ASSET_DIMS[asset]
        if not dims then return end
        local w, h = dims[1], dims[2]
        local n = #strips
        for i = 1, n do
            local top = math.floor((i - 1) * h / n)
            local bottom = math.floor(i * h / n)
            local st = strips[i]
            -- an image with fewer pixel rows than strips: the extra strips have no row to show, so hide them
            st.img.Visible = bottom > top
            if bottom > top then
                st.img.ImageRectOffset = Vector2.new(0, top)
                st.img.ImageRectSize = Vector2.new(w, bottom - top)
                st.y0 = top / h
                st.img.Size = UDim2.new(1, 0, (bottom - top) / h, 0)
            end
        end
    end
    if cfg.SliceGlitch then
        local N = cfg.SliceCount
        sliceMode = "rect"
        for _, set in ipairs(spriteSets) do
            for _, a in ipairs(set) do
                if not ASSET_DIMS[a] then sliceMode = "clip" end
            end
        end
        if sliceMode == "clip" then
            warn(TAG .. "SliceGlitch: some sprite sizes are unknown (rbxassetid images), so it uses clipping strips. "
                .. "clipping stops working while wobble/glitch/boil/sway rotates the sprite. use image links for exact slicing")
        end
        gui.ClipsDescendants = false -- strips slide past the sprite's edge, so don't clip at the billboard border

        for i = 1, N do
            local st = {amp = 0, ampTarget = 0, phase = math.random() * 6.2832, freq = 0.6 + math.random() * 0.8, gap = false}
            local img = Instance.new("ImageLabel")
            img.BackgroundTransparency = 1
            img.Image = sprite.Image
            img.ImageColor3 = sprite.ImageColor3
            img.ImageTransparency = sprite.ImageTransparency
            if cfg.PixelArt then img.ResampleMode = Enum.ResamplerMode.Pixelated end
            if sliceMode == "rect" then
                img.ZIndex = 10
                img.Parent = holder
            else
                local w = 1 + 2 * sliceMargin
                local frame = Instance.new("Frame")
                frame.BackgroundTransparency = 1
                frame.BorderSizePixel = 0
                frame.ClipsDescendants = true
                frame.Position = UDim2.new(-sliceMargin, 0, (i - 1) / N, 0)
                frame.Size = UDim2.new(w, 0, 1 / N, 0)
                frame.ZIndex = 10
                frame.Parent = holder
                img.Size = UDim2.new(1 / w, 0, N, 0)
                img.Position = UDim2.new(sliceMargin / w, 0, -(i - 1), 0)
                img.Parent = frame
                st.frame = frame
            end
            st.img = img
            strips[i] = st
        end
        sprite.Visible = false
        layoutStrips(sprite.Image)
    end

    -- preload (non-blocking: some executors hang PreloadAsync on custom files)
    local preloadFolder = Instance.new("Folder")
    preloadFolder.Name = "Preload"
    preloadFolder.Parent = gui
    local labels, seen = {}, {}
    for _, set in ipairs(spriteSets) do
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

    -- player might have reset while we were loading
    if not char:IsDescendantOf(game) or humanoid.Health <= 0 then
        gui:Destroy()
        wipeDownloads()
        return nil
    end

    -- afterimages (real ParticleEmitters).
    -- a particle can't change texture after it's emitted, so there is one emitter per sprite frame
    -- and we fire the one that matches the frame you're currently showing
    local trailHolder, trailPart
    local emitters, emitTimes = {}, {}
    -- follow-frame mode: every ghost is emitted from ALL the frame emitters at once, and only the emitter of the
    -- billboard's current frame has a visible size. so the ghosts follow the animation without any emitter ever
    -- swapping its Texture (swapping a live emitter's texture is what made ghosts flicker)
    local ghostSizeVisible, ghostSizeHidden, ghostFrameId, setGhostShape
    local ghostsReady = not cfg.AfterimageEffect -- ghosts are held back until their textures are preloaded
    local currentColor = view.tint
    local hoverOffset = 0
    local jumpOffset = 0 -- FrameJump's hop height, kept separate from hover so they just add together

    if cfg.AfterimageEffect then
        trailHolder = Instance.new("Folder")
        trailHolder.Name = "SkinBrainTrails"
        trailHolder.Parent = workspace

        trailPart = Instance.new("Part")
        trailPart.Name = "TrailAnchor"
        trailPart.Size = Vector3.new(0.2, 0.2, 0.2)
        trailPart.Transparency = 1
        trailPart.Anchored = true
        trailPart.CanCollide = false
        trailPart.CanQuery = false
        trailPart.CanTouch = false
        trailPart.CFrame = root.CFrame
        trailPart.Parent = trailHolder

        local attach = Instance.new("Attachment")
        attach.Parent = trailPart

        -- particles are square; Squash stretches them to your sprite's proportions
        -- (exact for square sprites like 8x8, best-effort for tall/wide ones)
        local spin = cfg.AfterimageDistort and cfg.AfterimageDistortRotation or 0

        -- ghost size + squash for a billboard of size sx x sy (it's recalculated when a phase changes the size).
        -- AfterimageDistort: every ghost gets its own random squash/stretch and size. the size runs from exactly
        -- the billboard's size up to (1 + amount) times bigger, so ghosts poke out a bit beyond it, and the
        -- squash makes each one wider and shorter, or taller and thinner. AfterimageDistortAmount = how much
        local function ghostShape(sx, sy)
            local aspect = sy / math.max(sx, 0.01)
            local squash = (aspect - 1) / (aspect + 1)
            local baseSize = sx / math.max(1 - squash, 0.013) * cfg.AfterimageSizeScale
            local endSize = baseSize * (1 + cfg.AfterimageGrow) -- default: same size the whole time, it only fades
            local d = cfg.AfterimageDistort and cfg.AfterimageDistortAmount or 0
            local sizeStart = baseSize * (1 + d / 2)
            local sizeFinish = endSize * (1 + d / 2)
            local envStart = baseSize * d / 2
            local envFinish = endSize * d / 2
            local squashEnv = math.min(d, math.max(0, 0.95 - math.abs(squash)))
            return NumberSequence.new({
                NumberSequenceKeypoint.new(0, sizeStart, envStart),
                NumberSequenceKeypoint.new(1, sizeFinish, envFinish),
            }), NumberSequence.new({
                NumberSequenceKeypoint.new(0, squash, squashEnv),
                NumberSequenceKeypoint.new(1, squash, squashEnv),
            })
        end
        local ghostSquash
        ghostSizeVisible, ghostSquash = ghostShape(view.sx, view.sy)
        ghostSizeHidden = NumberSequence.new(0)

        local function makeGhostEmitter(texture)
            local em = Instance.new("ParticleEmitter")
            em.Texture = texture
            em.Rate = 0 -- we emit by hand
            em.Enabled = true
            em.Speed = NumberRange.new(0)
            em.SpreadAngle = Vector2.new(0, 0)
            em.Acceleration = Vector3.new(0, 0, 0)
            em.Drag = 0
            em.Rotation = NumberRange.new(-spin, spin)
            em.RotSpeed = NumberRange.new(0)
            em.LockedToPart = false -- ghosts stay where they were emitted
            em.Orientation = Enum.ParticleOrientation.FacingCamera
            em.LightEmission = cfg.AfterimageLightEmission
            em.LightInfluence = cfg.LightInfluence
            em.ZOffset = cfg.AfterimageZOffset -- layering by render depth, no physical offset
            pcall(function() em.Brightness = cfg.AfterimageBrightness end)
            em.Lifetime = NumberRange.new(cfg.AfterimageFadeTime, cfg.AfterimageFadeTime)
            em.Color = ColorSequence.new(currentColor)
            em.Transparency = NumberSequence.new(cfg.AfterimageTransparency, 1)
            em.Size = ghostSizeVisible
            em.Squash = ghostSquash
            em.Parent = attach
            return em
        end

        -- one emitter per frame, each with its texture set once and never changed
        for _, set in ipairs(spriteSets) do
            for _, id in ipairs(set) do
                if not emitters[id] then emitters[id] = makeGhostEmitter(id) end
            end
        end
        if cfg.AfterimageFollowFrame then
            -- follow mode: only the current frame's emitter is visible (the others are size 0 until their frame comes)
            ghostFrameId = idle[1]
            for id, em in pairs(emitters) do
                if id ~= ghostFrameId then em.Size = ghostSizeHidden end
            end
        end

        setGhostShape = function(sx, sy)
            local sizeSeq, squashSeq = ghostShape(sx, sy)
            ghostSizeVisible = sizeSeq
            for id, em in pairs(emitters) do
                em.Squash = squashSeq
                if not (cfg.AfterimageFollowFrame and id ~= ghostFrameId) then em.Size = sizeSeq end
            end
        end

        -- preload + warm up. a texture an emitter hasn't drawn yet shows up a moment late, which looks like ghosts
        -- flickering or vanishing for a frame (worst with AfterimageFollowFrame, which keeps swapping the emitter's
        -- Texture). so: preload every texture, make each one draw once (tiny and almost invisible), and hold the
        -- real ghosts back until that's done
        local warm, seenTex, toPreload = {}, {}, {}
        for _, set in ipairs(spriteSets) do
            for _, id in ipairs(set) do
                if not seenTex[id] then
                    seenTex[id] = true
                    local w = Instance.new("ParticleEmitter")
                    w.Texture = id
                    w.Rate = 0
                    w.Speed = NumberRange.new(0)
                    w.LockedToPart = false
                    w.Lifetime = NumberRange.new(0.7, 0.7)
                    w.Size = NumberSequence.new(0.3)
                    w.Transparency = NumberSequence.new(0.98)
                    w.ZOffset = cfg.AfterimageZOffset
                    w.Parent = attach
                    warm[#warm + 1] = w
                    toPreload[#toPreload + 1] = w
                end
            end
        end
        task.spawn(function()
            local done = false
            local t0 = os.clock()
            task.spawn(function()
                pcall(ContentProvider.PreloadAsync, ContentProvider, toPreload)
                done = true
            end)
            while not done and os.clock() - t0 < 3 do task.wait(0.05) end
            if not alive then return end
            for _, w in ipairs(warm) do w:Emit(1) end -- each texture draws once...
            task.wait(0.35)                           -- ...and gets a few frames to be uploaded
            for _, w in ipairs(warm) do w:Destroy() end
            ghostsReady = true
            info(cfg, "afterimage textures preloaded")
        end)
    end

    local function spawnAfterimage(texture, moving)
        if not ghostsReady then return end
        if not emitters[texture] then return end

        local now = os.clock()

        -- cap how many ghosts are alive at once
        while emitTimes[1] and emitTimes[1] < now - cfg.AfterimageFadeTime do
            table.remove(emitTimes, 1)
        end
        if #emitTimes >= cfg.AfterimageMax then return end
        emitTimes[#emitTimes + 1] = now

        -- spawn exactly at the sprite's center. BillboardGui.StudsOffset is camera-relative, so the
        -- same camera-relative offset is used here (TBB turns an attachment to face the camera every
        -- frame for this). ghosts sit behind the sprite through the emitter's ZOffset (render depth)
        local cam = workspace.CurrentCamera
        local up = Vector3.new(view.ox, view.oy + hoverOffset, view.oz)
        local hop = Vector3.new(0, jumpOffset, 0) -- the hop is a world-space offset, like in the game
        trailPart.CFrame = CFrame.new(root.Position + (cam and cam.CFrame:VectorToWorldSpace(up) or up) + hop)

        local color = cfg.RainbowKeyframeColor and ColorSequence.new(currentColor) or nil
        if cfg.AfterimageFollowFrame then
            -- the same ghost is born in every frame emitter, only the current frame's one can be seen
            for _, em in pairs(emitters) do
                if color then em.Color = color end
                em:Emit(1)
            end
        else
            local em = emitters[texture]
            if color then em.Color = color end
            em:Emit(1)
        end
    end

    -- follow-frame mode: when the billboard changes frame, make that frame's emitter the visible one
    local function setGhostFrame(tex)
        if not (cfg.AfterimageFollowFrame and ghostSizeHidden) or ghostFrameId == tex then return end
        local old, new = emitters[ghostFrameId], emitters[tex]
        if old then old.Size = ghostSizeHidden end
        if new then new.Size = ghostSizeVisible end
        ghostFrameId = tex
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

    -- hide the overhead name/health bar (optional)
    local oldDisplayType
    if cfg.HideNameTag then
        oldDisplayType = humanoid.DisplayDistanceType
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end

    -- theme sounds: ThemeSound and ThemeSound2 (and their per-phase versions). every distinct track gets one looping
    -- Sound. the tracks of the CURRENT phase fade in and all the others fade out, so a phase change crossfades the
    -- music (PhaseAudioFade seconds). a track that two phases share just keeps playing
    local themeList = {}
    for _, rec in pairs(themeRecs) do
        if rec.src and resolved[rec.src] then
            local tc = rec.cfg
            local snd = Instance.new("Sound")
            snd.Name = "SkinBrainTheme"
            snd.SoundId = resolved[rec.src][1]
            snd.Volume = 0
            snd.Looped = true -- always loops until you reset/respawn
            snd.PlaybackSpeed = tc.PlaybackSpeed or 1
            if tc.RollOffMaxDistance then snd.RollOffMaxDistance = tc.RollOffMaxDistance end
            snd.Parent = root
            sounds[#sounds + 1] = snd
            rec.sound, rec.volume, rec.vol, rec.active, rec.nextCheck = snd, math.max(tonumber(tc.Volume) or 1, 0), 0, false, 0
            themeList[#themeList + 1] = rec
        end
    end

    local function updateThemes(dt, now)
        local fade = math.max(cfg.PhaseAudioFade, 0.01)
        for i = 1, #themeList do
            local rec = themeList[i]
            local snd = rec.sound
            local target = rec.active and rec.volume or 0
            local stepV = math.max(rec.volume, 0.01) * dt / fade
            if rec.vol < target then
                rec.vol = math.min(target, rec.vol + stepV)
            elseif rec.vol > target then
                rec.vol = math.max(target, rec.vol - stepV)
            end
            snd.Volume = rec.vol
            if rec.active or rec.vol > 0.001 then
                -- watchdog: if anything stops/pauses it, start it again
                if now >= rec.nextCheck then
                    rec.nextCheck = now + 1
                    snd.Looped = true
                    if not snd.Playing then snd:Play() end
                end
            elseif snd.Playing then
                snd:Stop()
            end
        end
    end

    -- voice lines: one random line every MinDelay..MaxDelay seconds, from the CURRENT phase's VoiceLines.
    -- lines never overlap (it waits for the current one to finish) and never loop. a phase change cuts the line
    -- that is playing and starts that phase's own timer
    local currentVoice, voicePlaying
    local anyVoice = false
    for _, rec in pairs(voiceRecs) do
        rec.sounds = {}
        local vc = rec.cfg
        for i, id in ipairs(rec.assets) do
            local vs = Instance.new("Sound")
            vs.Name = "SkinBrainVoice" .. i
            vs.SoundId = id
            vs.Volume = vc.Volume or 1
            vs.Looped = false
            if vc.RollOffMaxDistance then vs.RollOffMaxDistance = vc.RollOffMaxDistance end
            vs.Parent = root
            sounds[#sounds + 1] = vs
            rec.sounds[i] = vs
        end
        if #rec.sounds > 0 then anyVoice = true end
    end
    if anyVoice then
        task.spawn(function()
            local lastPick, scheduledFor, nextAt
            while alive do
                local rec = currentVoice
                if rec and #rec.sounds == 0 then rec = nil end
                if rec ~= scheduledFor then -- a phase with a different voice set started: restart the timer
                    scheduledFor = rec
                    lastPick = nil
                    if rec then
                        local minD = math.max(rec.cfg.MinDelay or 23, 0)
                        local maxD = math.max(rec.cfg.MaxDelay or 34, minD)
                        nextAt = os.clock() + minD + math.random() * (maxD - minD)
                    end
                end
                if rec and os.clock() >= nextAt then
                    local minD = math.max(rec.cfg.MinDelay or 23, 0)
                    local maxD = math.max(rec.cfg.MaxDelay or 34, minD)

                    -- random line, but not the same one twice in a row
                    local n = #rec.sounds
                    local pick = math.random(n)
                    if n > 1 and pick == lastPick then pick = pick % n + 1 end
                    lastPick = pick

                    local vs = rec.sounds[pick]
                    local startedAt = os.clock()
                    local finished = false
                    voicePlaying = vs
                    vs.TimePosition = 0
                    vs.Ended:Once(function() finished = true end)
                    vs:Play()
                    -- wait for it to end (timeout in case the sound never loads; a phase change cuts it short)
                    while alive and not finished and voicePlaying == vs and os.clock() - startedAt < 90 do task.wait(0.1) end
                    if voicePlaying == vs then voicePlaying = nil end

                    -- next line is timed from when this one started, but never before this one ended
                    if currentVoice == rec then
                        nextAt = math.max(os.clock(), startedAt + minD + math.random() * (maxD - minD))
                    end
                else
                    task.wait(0.25)
                end
            end
        end)
    end

    -- stomp sounds: a random footstep each time the walk frame switches, from the CURRENT phase's StompSound
    local lastStomp, lastStompPick = -1, nil
    for _, rec in pairs(stompRecs) do
        rec.sounds = {}
        local sc = rec.cfg
        for i, id in ipairs(rec.assets) do
            local ss = Instance.new("Sound")
            ss.Name = "SkinBrainStomp" .. i
            ss.SoundId = id
            ss.Volume = sc.Volume or 0.8
            ss.Looped = false
            if sc.RollOffMaxDistance then ss.RollOffMaxDistance = sc.RollOffMaxDistance end
            ss.Parent = root
            sounds[#sounds + 1] = ss
            rec.sounds[i] = ss
        end
        -- which walk frames get a footstep: all (default), odd (what the game does) or even
        rec.parity = tostring(sc.Frames or "all"):lower()
    end
    local curStomp -- the current phase's footstep set (nil = no footsteps), switched by applyPhase

    local function stompFrameOk(idx)
        local parity = curStomp and curStomp.parity or "all"
        if parity == "odd" then return idx % 2 == 1 end
        if parity == "even" then return idx % 2 == 0 end
        return true
    end

    local function playStomp()
        local set = curStomp
        local n = #set.sounds
        local pick = math.random(n)
        if n > 1 and pick == lastStompPick then pick = pick % n + 1 end -- no same footstep twice in a row
        lastStompPick = pick
        local ss = set.sounds[pick]
        local variation = set.cfg.PitchVariation or 0.08
        ss.PlaybackSpeed = 1 + (math.random() * 2 - 1) * variation
        ss.TimePosition = 0
        ss:Play()
    end

    -- PointLight modifier (optional). looks in your Head first, then anywhere in the character,
    -- and keeps watching in case the game removes/recreates the light
    local pl = type(cfg.PointLightModifier) == "table" and cfg.PointLightModifier or nil
    local lightRef, lightOriginal
    local plColor = (pl and pl.Color) and fixColor(pl.Color, cfg) or nil
    if pl and pl.Enabled then
        local function findLight()
            local head = char:FindFirstChild("Head")
            local light = head and head:FindFirstChildWhichIsA("PointLight")
            return light or char:FindFirstChildWhichIsA("PointLight", true)
        end
        task.spawn(function()
            local deadline = os.clock() + 6
            local light = findLight()
            while not light and alive and os.clock() < deadline do
                task.wait(0.25)
                light = findLight()
            end
            if not (light and alive) then
                if alive then warn(TAG .. "PointLightModifier: no PointLight found in your character (checked Head first)") end
                return
            end
            while alive do
                if not (light and light.Parent) then
                    light = findLight()
                    lightRef = nil
                end
                if light and light ~= lightRef then
                    lightOriginal = {
                        Color = light.Color, Brightness = light.Brightness,
                        Range = light.Range, Enabled = light.Enabled,
                    }
                    lightRef = light
                end
                task.wait(0.5)
            end
        end)
    end

    -- orbs (optional): balls / fire / smoke / sparkles / images circling you. client-side only
    local orbHolder, fieldVisual
    local orbs = {}
    if #orbSpecs > 0 then
        orbHolder = Instance.new("Folder")
        orbHolder.Name = "SkinBrainOrbs"
        orbHolder.Parent = workspace

        -- ShowField = true in OrbOrbit draws the field as a faint cylinder so you can tune FieldRadius/FieldHeight
        if orbCfg and orbCfg.ShowField then
            local fr = tonumber(orbCfg.FieldRadius) or 3
            local fh = tonumber(orbCfg.FieldHeight) or 4
            if fr > 0 then
                fieldVisual = Instance.new("Part")
                fieldVisual.Name = "FieldPreview"
                fieldVisual.Shape = Enum.PartType.Cylinder
                fieldVisual.Anchored = true
                fieldVisual.CanCollide = false
                fieldVisual.CanQuery = false
                fieldVisual.CanTouch = false
                fieldVisual.CastShadow = false
                fieldVisual.Material = Enum.Material.Neon
                fieldVisual.Color = Color3.fromRGB(90, 170, 255)
                fieldVisual.Transparency = 0.88
                fieldVisual.Size = Vector3.new(fh * 2, fr * 2, fr * 2) -- a cylinder's length runs along X
                fieldVisual.Parent = orbHolder
            end
        end

        local function makeOrbEmitter(kind, size, color, textureOverride)
            local em = Instance.new("ParticleEmitter")
            em.LockedToPart = false -- flames/sparks trail behind the orb as it moves
            em.Orientation = Enum.ParticleOrientation.FacingCamera
            em.Rotation = NumberRange.new(0, 360)
            if kind == "fire" then
                em.Texture = textureOverride or "rbxasset://textures/particles/fire_main.dds"
                em.Rate = 40
                em.Lifetime = NumberRange.new(0.35, 0.7)
                em.Speed = NumberRange.new(1, 3)
                em.SpreadAngle = Vector2.new(20, 20)
                em.Acceleration = Vector3.new(0, 6, 0)
                em.LightEmission = 1
                em.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, size * 0.9), NumberSequenceKeypoint.new(1, 0)})
                em.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
                em.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.4)),
                    ColorSequenceKeypoint.new(0.6, color),
                    ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.6)),
                })
            elseif kind == "smoke" then
                em.Texture = textureOverride or "rbxasset://textures/particles/smoke_main.dds"
                em.Rate = 14
                em.Lifetime = NumberRange.new(1.2, 2)
                em.Speed = NumberRange.new(0.5, 1.5)
                em.SpreadAngle = Vector2.new(25, 25)
                em.Acceleration = Vector3.new(0, 2, 0)
                em.LightEmission = 0
                em.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, size * 1.8)})
                em.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1)})
                em.Color = ColorSequence.new(color)
            else -- sparkles
                em.Texture = textureOverride or "rbxasset://textures/particles/sparkles_main.dds"
                em.Rate = 25
                em.Lifetime = NumberRange.new(0.4, 0.9)
                em.Speed = NumberRange.new(2, 5)
                em.SpreadAngle = Vector2.new(180, 180)
                em.Acceleration = Vector3.new(0, 0, 0)
                em.RotSpeed = NumberRange.new(-90, 90)
                em.LightEmission = 1
                em.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, size * 0.35), NumberSequenceKeypoint.new(1, 0)})
                em.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
                em.Color = ColorSequence.new(color)
            end
            return em
        end

        for _, spec in ipairs(orbSpecs) do
            local size = math.max(spec.Size, 0.1)
            local part = Instance.new("Part")
            part.Name = "Orb"
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.CastShadow = false
            part.Size = Vector3.new(size, size, size)
            part.CFrame = root.CFrame
            part.Transparency = 1

            local orb = {part = part, spec = spec, phase = spec.phase}
            local ok = true

            if spec.Type == "ball" then
                if tostring(spec.Material or ""):lower() == "flat" then
                    -- an unlit flat circle: shows exactly the color you picked (no glow, no lighting)
                    part.Transparency = 1
                    local bb = Instance.new("BillboardGui")
                    bb.Size = UDim2.new(size, 0, size, 0)
                    bb.AlwaysOnTop = false
                    bb.LightInfluence = 0
                    bb.Parent = part
                    local dot = Instance.new("Frame")
                    dot.Size = UDim2.new(1, 0, 1, 0)
                    dot.BorderSizePixel = 0
                    dot.BackgroundColor3 = spec.Color
                    dot.BackgroundTransparency = math.clamp(spec.Transparency, 0, 1)
                    dot.Parent = bb
                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0.5, 0)
                    corner.Parent = dot
                else
                    part.Shape = Enum.PartType.Ball
                    local okMat, mat = pcall(function() return Enum.Material[spec.Material or "Neon"] end)
                    part.Material = (okMat and mat) or Enum.Material.Neon
                    part.Color = spec.Color
                    part.Transparency = math.clamp(spec.Transparency, 0, 1)
                end
            elseif spec.Type == "fire" and not spec.texture then
                -- the classic Fire object takes its two colors directly. (the particle fire texture is
                -- itself orange, so a pale color you pick always came out saturated and bright)
                -- unless you pick colors, fire gets the same colors Roblox gives a brand new Fire:
                -- orange outer flames (236,139,70) and brown inner flames (139,80,55)
                local fireColor = fixColor(spec.fireColor or Color3.fromRGB(236, 139, 70), cfg)
                local fireColor2 = spec.SecondaryColor or fixColor(Color3.fromRGB(139, 80, 55), cfg)

                -- FireRate works like a particle emitter's Rate: 1 = normal, 2 = twice as many flames,
                -- 0.5 = half as many. the Fire object has no Rate of its own, so above 1 extra Fire objects
                -- are stacked, and a fraction is done by switching a Fire on and off very fast
                local rate = math.clamp(spec.FireRate or 1, 0, 10)
                local copies = math.max(1, math.ceil(rate))
                orb.fires = {}
                for i = 1, copies do
                    local fire = Instance.new("Fire")
                    fire.Color = fireColor
                    fire.SecondaryColor = fireColor2
                    fire.Heat = spec.Heat or 9
                    fire.Size = math.clamp(spec.FireSize or size * 2.5, 2, 30)
                    fire.Parent = part
                    local duty = math.clamp(rate - (i - 1), 0, 1)
                    if duty < 1 then
                        orb.fires[#orb.fires + 1] = {fire = fire, duty = duty}
                        fire.Enabled = duty > 0
                    end
                end
                if #orb.fires == 0 then orb.fires = nil end
            elseif spec.Type == "fire" or spec.Type == "smoke" or spec.Type == "sparkles" then
                -- (fire only lands here when you gave the orb your own flame Texture)
                makeOrbEmitter(spec.Type, size, spec.Color, spec.texture).Parent = part
            elseif spec.Type == "image" then
                if #spec.frames == 0 then
                    warn(TAG .. "an image orb has no usable Image, skipping it")
                    ok = false
                else
                    local bb = Instance.new("BillboardGui")
                    bb.Size = UDim2.new(size, 0, size, 0)
                    bb.AlwaysOnTop = false
                    bb.LightInfluence = cfg.LightInfluence
                    bb.Parent = part
                    local img = Instance.new("ImageLabel")
                    img.Size = UDim2.new(1, 0, 1, 0)
                    img.BackgroundTransparency = 1
                    img.Image = spec.frames[1]
                    img.ImageColor3 = spec.ImageColor or Color3.new(1, 1, 1)
                    img.ImageTransparency = math.clamp(spec.Transparency, 0, 1)
                    if cfg.PixelArt then img.ResampleMode = Enum.ResamplerMode.Pixelated end
                    img.Parent = bb
                    orb.img = img
                    orb.frames = spec.frames
                end
            else
                warn(TAG .. "unknown orb Type '" .. tostring(spec.Type) .. "' (use Ball, Fire, Smoke, Sparkles or Image)")
                ok = false
            end

            if ok then
                part.Parent = orbHolder
                orbs[#orbs + 1] = orb
            else
                part:Destroy()
            end
        end
    end

    -- reactive sounds (optional): sounds that react to what you're doing.
    --   walk / run / idle / move : play (looping) while that is true and fade out when it stops.
    --                              with Loop = false they play once each time you enter that state instead
    --   start / stop             : once when you start / stop moving
    --   jump / land              : once when you jump / land
    -- "run" means your running speed is at or above ReactiveSounds.RunSpeed, "walk" is moving slower than that
    local reactives = {} -- the CURRENT phase's entries (switched by applyPhase)
    local reactiveRunSpeed = 20
    local pendingJump, pendingLand = false, false
    local anyReactive = false
    for _, rec in pairs(reactiveRecs) do
        rec.entries = {}
        for _, spec in ipairs(rec.specs) do
            if #spec.assets == 0 then
                warn(TAG .. "reactive sound " .. spec.index .. " (" .. spec.when .. ") has no usable Sound, skipping it")
            else
                local r = {
                    spec = spec, when = spec.when, sounds = {}, lastPlay = -1e9, vol = 0, active = false,
                    volume = math.max(tonumber(spec.Volume) or 1, 0),
                    fade = math.max(tonumber(spec.Fade) or 0.15, 0.01),
                    cooldown = math.max(tonumber(spec.Cooldown) or 0.2, 0),
                    pitch = math.max(tonumber(spec.PitchVariation) or 0, 0),
                    speed = tonumber(spec.PlaybackSpeed) or 1,
                }
                r.looping = (r.when == "walk" or r.when == "run" or r.when == "idle" or r.when == "move") and spec.Loop ~= false
                for i, id in ipairs(spec.assets) do
                    local rs = Instance.new("Sound")
                    rs.Name = "SkinBrainReactive" .. spec.index .. "_" .. i
                    rs.SoundId = id
                    rs.Volume = r.looping and 0 or r.volume
                    rs.Looped = r.looping
                    rs.PlaybackSpeed = r.speed
                    if tonumber(spec.RollOffMaxDistance) then rs.RollOffMaxDistance = tonumber(spec.RollOffMaxDistance) end
                    rs.Parent = root
                    sounds[#sounds + 1] = rs
                    r.sounds[i] = rs
                end
                rec.entries[#rec.entries + 1] = r
            end
        end
        if #rec.entries > 0 then anyReactive = true end
    end
    if anyReactive then
        conns[#conns + 1] = humanoid.StateChanged:Connect(function(_, new)
            if new == Enum.HumanoidStateType.Jumping then
                pendingJump = true
            elseif new == Enum.HumanoidStateType.Landed then
                pendingLand = true
            end
        end)
    end
    local prevMoving, prevRunning = false, false

    local function updateReactive(dt, now, moving, speed)
        if #reactives == 0 then return end
        local running = moving and speed >= reactiveRunSpeed
        local walking = moving and not running
        local jumped, landed = pendingJump, pendingLand
        pendingJump, pendingLand = false, false

        for i = 1, #reactives do
            local r = reactives[i]
            local when = r.when
            local cond
            if when == "walk" then cond = walking
            elseif when == "run" then cond = running
            elseif when == "idle" then cond = not moving
            elseif when == "move" then cond = moving end

            if r.looping then
                -- plays while the state is true, fading in and out so it never cuts off hard
                if cond and not r.active then
                    r.active = true
                    if not r.current then -- (if it was still fading out, just bring it back up)
                        r.current = r.sounds[math.random(#r.sounds)]
                        r.current.Volume = r.vol
                        r.current:Play()
                    end
                elseif not cond and r.active then
                    r.active = false
                end
                local target = cond and r.volume or 0
                local stepV = math.max(r.volume, 0.01) * dt / r.fade
                if r.vol < target then
                    r.vol = math.min(target, r.vol + stepV)
                elseif r.vol > target then
                    r.vol = math.max(target, r.vol - stepV)
                end
                if r.current then
                    r.current.Volume = r.vol
                    if r.vol <= 0.001 and not r.active then
                        r.current:Stop()
                        r.current = nil
                    end
                end
            else
                -- one-shots
                local fire = false
                if when == "start" then
                    fire = moving and not prevMoving
                elseif when == "stop" then
                    fire = (not moving) and prevMoving
                elseif when == "jump" then
                    fire = jumped
                elseif when == "land" then
                    fire = landed
                else -- walk/run/idle/move with Loop = false: once each time you enter that state
                    local was
                    if when == "walk" then was = prevMoving and not prevRunning
                    elseif when == "run" then was = prevRunning
                    elseif when == "idle" then was = not prevMoving
                    else was = prevMoving end
                    fire = cond and not was
                end
                if fire and now - r.lastPlay >= r.cooldown then
                    r.lastPlay = now
                    local snd = r.sounds[math.random(#r.sounds)]
                    if r.pitch > 0 then snd.PlaybackSpeed = r.speed * (1 + (math.random() * 2 - 1) * r.pitch) end
                    snd.TimePosition = 0
                    snd:Play()
                end
            end
        end
        prevMoving, prevRunning = moving, running
    end

    -- scare event (optional, TBB style): every ScareInterval seconds ONE scare plays. a scare is an image shown over
    -- your skin (its own billboard, in front) plus a sound, and it ends when the sound ends: the image disappears and
    -- anything hidden for it (your skin / the afterimage) comes back. the main scare and every ScareVariants entry
    -- are the pool, and one is picked each time (random without repeating, or in order)
    local scares = {}
    local scareActive = false
    local scareHideGhosts = false
    if cfg.ScareEvent then
        for _, sp in ipairs(scareSpecs) do
            local sc = {spec = sp, sounds = {}}
            if #sp.images > 0 then
                local sx, sy = tonumber(sp.SizeX) or cfg.sizeX, tonumber(sp.SizeY) or cfg.sizeY
                local g = Instance.new("BillboardGui")
                g.Name = "SkinBrainScare"
                g.ResetOnSpawn = false
                g.ClipsDescendants = false
                g.AlwaysOnTop = cfg.AlwaysOnTop
                g.LightInfluence = cfg.LightInfluence
                g.Size = UDim2.new(sx, 0, sy, 0)
                sc.offset = Vector3.new(tonumber(sp.StudsOffsetX) or 0, tonumber(sp.StudsOffsetY) or 0, tonumber(sp.StudsOffsetZ) or 0)
                g.StudsOffset = sc.offset
                pcall(function() g.Brightness = math.max(tonumber(sp.Brightness) or 1, 0) end)
                g.Enabled = false
                g.Parent = root
                local im = Instance.new("ImageLabel")
                im.Size = UDim2.new(1, 0, 1, 0)
                im.BackgroundTransparency = 1
                im.Image = sp.images[1]
                if cfg.PixelArt then im.ResampleMode = Enum.ResamplerMode.Pixelated end
                im.Parent = g
                sc.gui, sc.img, sc.sx, sc.sy = g, im, sx, sy
            else
                warn(("%sscare '%s' has no usable image, it will only play its sound"):format(TAG, sp.label))
            end
            for i, id in ipairs(sp.sounds) do
                local sn = Instance.new("Sound")
                sn.Name = "SkinBrainScareSound"
                sn.SoundId = id
                sn.Volume = math.clamp(tonumber(sp.Volume) or cfg.ScareVolume, 0, 10)
                sn.Looped = false
                sn.RollOffMaxDistance = 100000
                sn.Parent = root
                sounds[#sounds + 1] = sn
                sc.sounds[i] = sn
            end
            if sc.gui or #sc.sounds > 0 then
                scares[#scares + 1] = sc
            else
                warn(("%sscare '%s' has neither a usable image nor sound, skipping it"):format(TAG, sp.label))
            end
        end
        if #scares == 0 then
            warn(TAG .. "ScareEvent is on but there is no scare to play (check ScareImage / ScareSound / ScareVariants)")
        else
            info(cfg, ("%d scare(s) ready: %s"):format(#scares, (function()
                local names = {}
                for _, sc in ipairs(scares) do names[#names + 1] = sc.spec.label end
                return table.concat(names, ", ")
            end)()))

            task.spawn(function()
                local lastPick, orderIdx = nil, 0
                local nextAt = os.clock() + cfg.ScareInterval
                while alive do
                    while alive and os.clock() < nextAt do task.wait(0.25) end
                    if not alive then break end

                    -- the phase this scare switches you into. a scare can be tied to a phase with Phase = "Name":
                    -- it then only plays when that phase is the one about to start
                    local nextPhase = (#phases > 1) and (phaseIndex % #phases + 1) or nil
                    local function eligible(sc)
                        local want = sc.spec.Phase
                        if want == nil or not nextPhase then return true end
                        return tostring(want):lower() == phases[nextPhase].name:lower()
                    end
                    local anyEligible = false
                    for _, sc in ipairs(scares) do
                        if eligible(sc) then anyEligible = true break end
                    end
                    local function ok(i) return (not anyEligible) or eligible(scares[i]) end

                    -- which scare: in order, or random by weight (never the same one twice in a row)
                    local pick
                    if cfg.ScarePick == "order" then
                        for _ = 1, #scares do
                            orderIdx = orderIdx % #scares + 1
                            if ok(orderIdx) then pick = orderIdx break end
                        end
                    else
                        local total = 0
                        for i, sc in ipairs(scares) do
                            if ok(i) and not (#scares > 1 and i == lastPick) then total += sc.spec.weight end
                        end
                        local roll = math.random() * total
                        for i, sc in ipairs(scares) do
                            if ok(i) and not (#scares > 1 and i == lastPick) then
                                pick = pick or i
                                roll -= sc.spec.weight
                                if roll <= 0 then pick = i break end
                            end
                        end
                    end
                    if not pick then
                        for i in ipairs(scares) do
                            if ok(i) then pick = i break end
                        end
                    end
                    pick = pick or 1
                    lastPick = pick
                    local sc = scares[pick]
                    local sp = sc.spec
                    info(cfg, "scare: " .. sp.label)

                    -- scare starts
                    local startedAt = os.clock()
                    local hideBear, hideGhosts = sp.RemoveBear == true, sp.RemoveAfterimage == true
                    scareActive = true
                    scareHideGhosts = hideGhosts
                    if sc.gui then sc.gui.Enabled = true end
                    if hideBear then gui.Enabled = false end
                    if hideGhosts then
                        for _, em in pairs(emitters) do em:Clear() end
                    end
                    -- phase change at the start of the scare (your skin may be hidden right now, so it changes unseen)
                    if nextPhase and cfg.PhaseChangeAt == "start" then applyPhase(nextPhase) end

                    local snd = (#sc.sounds > 0) and sc.sounds[math.random(#sc.sounds)] or nil
                    local finished = false
                    if snd then
                        snd.TimePosition = 0
                        snd.Ended:Once(function() finished = true end)
                        snd:Play()
                    end
                    local shake = math.max(tonumber(sp.Shake) or 0, 0)
                    local zoomFrom = tonumber(sp.ZoomFrom) or 1
                    local zoomTime = math.max(tonumber(sp.ZoomTime) or 0.25, 0.01)
                    local fadeOut = math.max(tonumber(sp.FadeOut) or 0, 0)
                    local blink = math.max(tonumber(sp.Blink) or 0, 0)
                    local frameSpeed = math.max(tonumber(sp.ImageFrameSpeed) or 0.1, 0.02)

                    -- ...and ends when the sound ends (with a safety limit so your skin can never get stuck hidden)
                    while alive do
                        local elapsed = os.clock() - startedAt
                        local remaining
                        if snd then
                            if finished then break end
                            local len = snd.TimeLength
                            local limit = (len > 0) and (len / math.max(snd.PlaybackSpeed, 0.1) + 1.5) or 8
                            if elapsed > limit then break end
                            if len > 0 then remaining = len - snd.TimePosition end
                        else
                            if elapsed >= cfg.ScareFallbackTime then break end
                            remaining = cfg.ScareFallbackTime - elapsed
                        end
                        if sc.gui then
                            if zoomFrom ~= 1 then -- grows from ZoomFrom x its size to full size
                                local z = zoomFrom + (1 - zoomFrom) * math.clamp(elapsed / zoomTime, 0, 1)
                                sc.gui.Size = UDim2.new(sc.sx * z, 0, sc.sy * z, 0)
                            end
                            if shake > 0 then
                                sc.gui.StudsOffset = sc.offset + Vector3.new((math.random() * 2 - 1) * shake, (math.random() * 2 - 1) * shake, 0)
                            end
                            if #sp.images > 1 then
                                sc.img.Image = sp.images[math.floor(elapsed / frameSpeed) % #sp.images + 1]
                            end
                            if blink > 0 then sc.img.Visible = math.floor(elapsed * blink * 2) % 2 == 0 end
                            if fadeOut > 0 and remaining then
                                sc.img.ImageTransparency = math.clamp(1 - remaining / fadeOut, 0, 1)
                            end
                        end
                        task.wait()
                    end

                    -- scare over: image goes away, everything comes back
                    if sc.gui then
                        sc.gui.Enabled = false
                        sc.gui.StudsOffset = sc.offset
                        sc.gui.Size = UDim2.new(sc.sx, 0, sc.sy, 0)
                        sc.img.Visible = true
                        sc.img.ImageTransparency = 0
                        sc.img.Image = sp.images[1]
                    end
                    if nextPhase and cfg.PhaseChangeAt == "end" then applyPhase(nextPhase) end
                    if hideBear then gui.Enabled = true end
                    scareActive = false
                    scareHideGhosts = false
                    nextAt = math.max(os.clock(), startedAt + (tonumber(sp.Interval) or cfg.ScareInterval))
                end
            end)
        end
    end

    -- extra billboards (optional): each one is its own BillboardGui with its own frames, clocks, size, offset and mode.
    -- ZOffset (or studsOffsetZ) layers it: positive = in front of your main skin, negative = behind it.
    -- it moves along the camera's view direction, so it changes the draw order without moving it on screen
    local extras = {}
    for _, spec in ipairs(extraSpecs) do
        if #spec.idle == 0 then
            warn(TAG .. "ExtraBillboards entry " .. spec.index .. " has no usable Idle/Walk sprites, skipping it")
        else
            local e = {spec = spec, idle = spec.idle, walk = spec.walk}
            local egui = Instance.new("BillboardGui")
            egui.Name = "SkinBrainExtra" .. spec.index
            egui.ResetOnSpawn = false
            egui.ClipsDescendants = false
            egui.AlwaysOnTop = (spec.AlwaysOnTop == nil) and cfg.AlwaysOnTop or spec.AlwaysOnTop == true
            egui.LightInfluence = math.clamp(tonumber(spec.LightInfluence) or cfg.LightInfluence, 0, 1)
            pcall(function() egui.Brightness = tonumber(spec.Brightness) or cfg.Brightness end)
            egui.Size = UDim2.new(tonumber(spec.sizeX) or cfg.sizeX, 0, tonumber(spec.sizeY) or cfg.sizeY, 0)
            egui.StudsOffset = Vector3.new(tonumber(spec.studsOffsetX) or 0,
                tonumber(spec.studsOffsetY) or cfg.studsOffsetY, tonumber(spec.ZOffset) or tonumber(spec.studsOffsetZ) or 0)
            egui.Parent = root

            local eimg = Instance.new("ImageLabel")
            eimg.Size = UDim2.new(1, 0, 1, 0)
            eimg.BackgroundTransparency = 1
            eimg.Image = e.idle[1]
            eimg.ImageColor3 = (typeof(spec.Tint) == "Color3") and fixColor(spec.Tint, cfg) or cfg.Tint
            eimg.ImageTransparency = math.clamp(tonumber(spec.Transparency) or cfg.Transparency, 0, 1)
            local pixel = cfg.PixelArt
            if spec.PixelArt ~= nil then pixel = spec.PixelArt == true end
            if pixel then eimg.ResampleMode = Enum.ResamplerMode.Pixelated end
            eimg.Parent = egui

            local stepD = tonumber(spec.StepDelay) or cfg.StepDelay
            e.idleClock = makeClock(#e.idle, spec.IdleFrameCycle == true,
                tonumber(spec.IdleFrameSwitchSpeed) or stepD, spec.IdleFrameDelays)
            e.walkClock = makeClock(#e.walk, spec.WalkFrameCycle == true,
                tonumber(spec.WalkFrameSwitchSpeed) or stepD, spec.WalkFrameDelays)
            local mode = tostring(spec.FrameMode or "auto"):lower()
            if mode ~= "auto" and mode ~= "idle" and mode ~= "walk" and mode ~= "reverse" then mode = "auto" end
            e.mode = mode
            e.jump = spec.FrameJump == true
            -- its own timing: StepDelay / *FrameSwitchSpeed / *FrameDelays above, and its own ScaleWalkWithSpeed too
            e.scaleWalk = (spec.ScaleWalkWithSpeed == nil) and cfg.ScaleWalkWithSpeed or spec.ScaleWalkWithSpeed == true
            local style = tostring(spec.FrameBounceStyle or cfg.FrameBounceStyle):lower()
            e.style = (style == "alternate") and "alternate" or "step"
            e.bounce = {y = 0, r = 0, fromY = 0, fromR = 0}
            e.jumpH = math.max(tonumber(spec.FrameJumpHighestHeight) or cfg.FrameJumpHighestHeight, 0)
            e.skipJump = toIndexSet(spec.FrameSkipJump, "ExtraBillboards[" .. spec.index .. "].FrameSkipJump")
            e.sway = tonumber(spec.FrameSwayAmount) or 0
            e.gui, e.img, e.tex = egui, eimg, e.idle[1]
            e.idleTime, e.walkTime, e.hopY, e.swayR = 0, 0, 0, 0
            extras[#extras + 1] = e
        end
    end

    local function updateExtra(e, dt, moving, rawMul)
        local animWalk = animWalkFor(e.mode, moving)
        local tex, idx, p, stepNo
        if animWalk then
            e.walkTime += dt * (e.scaleWalk and rawMul or 1)
            e.idleTime = 0
            idx, p, stepNo = e.walkClock(e.walkTime)
            tex = e.walk[idx]
        else
            e.idleTime += dt
            e.walkTime = 0
            tex = e.idle[e.idleClock(e.idleTime)]
        end
        if tex ~= e.tex then
            e.tex = tex
            e.img.Image = tex
        end
        if e.jump or e.sway ~= 0 then
            local h, r = stepBounce(e.bounce, e.style, animWalk, idx, p, stepNo,
                e.jump and e.jumpH or 0, e.sway, e.skipJump, dt)
            if e.jump then e.gui.StudsOffsetWorldSpace = Vector3.new(0, h, 0) end
            e.img.Rotation = r
        end
    end

    -- main loop
    local walkClock, idleClock -- built for the current phase by applyPhase
    local walkTime, idleTime = 0, 0
    local activeTexture = idle[1]
    local squashY = 1
    local glitch = {x = 0, y = 0, z = 0, rot = 0, scale = 1}
    local nextGlitch, lastTrail = 0, 0

    local transformActive = cfg.FrameJiggle or cfg.GlitchEffect or cfg.WobbleEffect
        or cfg.HoverBob or cfg.BreathEffect or cfg.BoilEffect or cfg.FrameJump or cfg.FrameSwayAmount ~= 0
    local alphaActive = cfg.GhostPulse or cfg.FlickerEffect
    local amp = {wobble = 0, hover = 0, breath = 0}
    local boil = {rot = 0, x = 0, y = 0}
    local nextBoil, flickerUntil, lastAlpha = 0, 0, -1

    -- FrameSkipJump / FrameSkipJiggle: walk frame numbers to leave out. bad or empty lists skip nothing
    local skipJump = toIndexSet(cfg.FrameSkipJump, "FrameSkipJump")
    local skipJiggle = toIndexSet(cfg.FrameSkipJiggle, "FrameSkipJiggle")
    local skipStomp = toIndexSet(cfg.FrameSkipStomp, "FrameSkipStomp")
    local lastDebugIdx
    local bounce = {y = 0, r = 0, fromY = 0, fromR = 0} -- state for stepBounce
    local jiggleEasing = false

    -- orb patterns. offsets are around you, in world axes (so they don't turn when you turn)
    local function orbOffset(sp, a)
        local D = sp.Distance
        local pat = sp.Pattern
        if pat == "figure8" then
            return Vector3.new(math.cos(a) * D, 0, math.sin(2 * a) * D * 0.5)
        elseif pat == "spiral" then
            -- radius breathes between 20% and 100% of Distance (out for one orbit, back in for the next)
            local r = D * (0.2 + 0.8 * (0.5 - 0.5 * math.cos(a * 0.5)))
            return Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
        elseif pat == "flower" then
            local r = D * math.cos((sp.PatternPetals or 3) * a)
            return Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
        end
        return Vector3.new(math.cos(a) * D, 0, math.sin(a) * D) -- circle
    end

    -- snake pattern: each orb sits where you were a moment ago (orb 1 = SnakeSpacing seconds ago, orb 2 = twice that...)
    local pathHist = {}
    local usesSnake, maxSnakeDelay = false, 0
    for _, o in ipairs(orbs) do
        if o.spec.Pattern == "snake" then
            usesSnake = true
            maxSnakeDelay = math.max(maxSnakeDelay, o.spec.index * (o.spec.SnakeSpacing or 0.3))
        end
    end
    local function pathAt(T)
        local n = #pathHist
        if n == 0 then return root.Position end
        if T >= pathHist[n].t then return pathHist[n].p end
        for k = n - 1, 1, -1 do
            local p0, p1 = pathHist[k], pathHist[k + 1]
            if T >= p0.t then
                return p0.p:Lerp(p1.p, (T - p0.t) / math.max(p1.t - p0.t, 1e-4))
            end
        end
        return pathHist[1].p
    end

    -- invisible magnetic field around you: an orb is never allowed inside it. orbs that would pass through
    -- you (figure8, flower, spiral, snake...) swing around the edge of the field instead of crossing it.
    -- outside the field's soft edge nothing is changed at all, so normal orbits stay exactly as they were
    local FIELD_SOFT = 0.5 -- studs of smooth easing at the edge, so orbs curve away instead of bumping
    local function applyField(o, sp, off, y, dt)
        local fr = tonumber(sp.FieldRadius) or 0
        if fr <= 0 or math.abs(y) > (tonumber(sp.FieldHeight) or 4) + sp.Size / 2 then
            o.fieldAng, o.fieldCatching = nil, false -- no field (or the orb is above/below you)
            return off
        end
        local R = fr + sp.Size / 2 -- the orb's surface stays out of the field, not just its center
        local x, z = off.X, off.Z
        local r = math.sqrt(x * x + z * z)
        local rawAng = math.atan2(z, x)
        if r >= R + FIELD_SOFT and not o.fieldCatching then
            o.fieldAng = rawAng -- far away: follow the pattern exactly
            return off
        end

        -- near the field: the orb's angle around you may only turn so fast, so when its path would go
        -- straight through you it slides around the edge instead of jumping to the other side
        local ang = o.fieldAng or rawAng
        local diff = 0
        if r > 0.05 then
            diff = (rawAng - ang + math.pi) % (2 * math.pi) - math.pi
            if math.abs(diff) > math.pi - 0.2 then
                diff = (sp.Speed >= 0 and 1 or -1) * math.abs(diff) -- dead ahead: go around the way it orbits
            end
        end
        local maxStep = math.max(3, 3 * 2 * math.pi * math.abs(sp.Speed)) * dt
        if math.abs(diff) <= maxStep then
            ang += diff
            o.fieldCatching = false
        else
            ang += (diff > 0 and 1 or -1) * maxStep
            o.fieldCatching = true
        end
        o.fieldAng = ang

        -- distance from you: never less than R, easing smoothly into the pattern's own distance
        local s = r - R
        local rad
        if s >= FIELD_SOFT then
            rad = r
        elseif s <= -FIELD_SOFT then
            rad = R
        else
            rad = R + (s + FIELD_SOFT) ^ 2 / (4 * FIELD_SOFT)
        end
        return Vector3.new(math.cos(ang) * rad, off.Y, math.sin(ang) * rad)
    end

    -- the game decides walk vs idle from Humanoid.Running (speed above a small threshold), not from input
    local runSpeed = 0
    conns[#conns + 1] = humanoid.Running:Connect(function(speed) runSpeed = speed end)
    local stripImage
    local sliceNextRoll = 0

    -- ===== phases =====
    -- a phase = your main settings + what that phase changes. applyPhase switches the sprites, timing, live effect
    -- settings and the billboard's size / offset / tint / brightness (blended over PhaseBlendTime if you set one)
    local baseLive = {}
    for _, k in ipairs(PHASE_LIVE) do baseLive[k] = cfg[k] end
    local blend

    -- puts the current view (size, offset, tint...) onto the billboard
    local function pushView()
        gui.Size = UDim2.new(view.sx, 0, view.sy, 0)
        if not transformActive then gui.StudsOffset = Vector3.new(view.ox, view.oy, view.oz) end
        pcall(function() gui.Brightness = view.brightness end)
        if not cfg.RainbowKeyframeColor then
            currentColor = view.tint
            sprite.ImageColor3 = view.tint
            local seq = ColorSequence.new(view.tint)
            for _, em in pairs(emitters) do em.Color = seq end
        end
        if not alphaActive then sprite.ImageTransparency = view.transparency end
        lastAlpha = -1
    end

    applyPhase = function(i, instant)
        local ph = phases[i]
        local sp = ph.spec
        phaseIndex = i

        -- sprites + timing (a phase's StepDelay sets both speeds unless it sets idle/walk speeds itself)
        idle, walk = ph.idle, ph.walk
        local function speedFor(key)
            return tonumber(sp[key]) or tonumber(sp.StepDelay) or cfg[key] or cfg.StepDelay
        end
        local function opt(key)
            if sp[key] ~= nil then return sp[key] end
            return cfg[key]
        end
        walkClock = makeClock(#walk, opt("WalkFrameCycle") == true, math.max(speedFor("WalkFrameSwitchSpeed"), 0.01), opt("WalkFrameDelays"))
        idleClock = makeClock(#idle, opt("IdleFrameCycle") == true, math.max(speedFor("IdleFrameSwitchSpeed"), 0.01), opt("IdleFrameDelays"))

        -- live effect settings: whatever the phase sets, everything else goes back to your main settings
        for _, k in ipairs(PHASE_LIVE) do
            local v = sp[k]
            if v ~= nil and typeof(v) ~= typeof(baseLive[k]) then
                warn(("%sphase '%s': %s should be a %s, ignoring it"):format(TAG, ph.name, k, typeof(baseLive[k])))
                v = nil
            end
            if v == nil then v = baseLive[k] end
            cfg[k] = v
        end
        local fm = tostring(cfg.FrameMode):lower()
        if fm ~= "auto" and fm ~= "idle" and fm ~= "walk" and fm ~= "reverse" then fm = "auto" end
        cfg.FrameMode = fm
        cfg.FrameBounceStyle = (tostring(cfg.FrameBounceStyle):lower() == "alternate") and "alternate" or "step"
        transformActive = cfg.FrameJiggle or cfg.GlitchEffect or cfg.WobbleEffect or cfg.HoverBob
            or cfg.BreathEffect or cfg.BoilEffect or cfg.FrameJump or cfg.FrameSwayAmount ~= 0
        alphaActive = cfg.GhostPulse or cfg.FlickerEffect

        -- an effect that just switched off must not leave the skin stuck in its last pose
        if not cfg.FrameJump then
            jumpOffset = 0
            bounce.y = 0
            gui.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
        end
        if cfg.FrameSwayAmount == 0 then bounce.r = 0 end
        if not transformActive then
            squashY, hoverOffset = 1, 0
            glitch.x, glitch.y, glitch.z, glitch.rot, glitch.scale = 0, 0, 0, 0, 1
            boil.rot, boil.x, boil.y = 0, 0, 0
            amp.wobble, amp.hover, amp.breath = 0, 0, 0
            holder.Rotation = 0
            holder.Size = UDim2.new(1, 0, 1, 0)
            holder.Position = UDim2.new(0.5, 0, 1, 0)
        end
        if not alphaActive then
            for n = 1, #layers do layers[n].gui.ImageTransparency = layers[n].base end
        end

        -- size / offset / tint / brightness
        local to = ph.view
        if instant or cfg.PhaseBlendTime <= 0 then
            for k, v in pairs(to) do view[k] = v end
            blend = nil
            pushView()
        else
            local from = {}
            for k, v in pairs(view) do from[k] = v end
            blend = {t0 = os.clock(), from = from, to = to}
        end
        if setGhostShape then setGhostShape(to.sx, to.sy) end -- ghosts are sized for the new billboard

        -- audio for this phase: this phase's theme tracks fade in and the others fade out (a track both phases
        -- share just keeps going), and voice lines / footsteps / reactive sounds switch to this phase's own sets
        for _, rec in ipairs(themeList) do
            rec.active = (rec == ph.themeRec or rec == ph.theme2Rec)
            if instant then rec.vol = rec.active and rec.volume or 0 end -- the very first phase starts right away
        end
        if currentVoice ~= ph.voiceRec then
            if voicePlaying then
                voicePlaying:Stop()
                voicePlaying = nil
            end
            currentVoice = ph.voiceRec
        end
        curStomp = (ph.stompRec and #ph.stompRec.sounds > 0) and ph.stompRec or nil
        local newEntries = ph.reactiveRec and ph.reactiveRec.entries or {}
        if newEntries ~= reactives then
            for _, r in ipairs(reactives) do -- silence the old phase's reactive sounds
                r.vol, r.active, r.current = 0, false, nil
                for _, rs in ipairs(r.sounds) do rs:Stop() end
            end
            reactives = newEntries
        end
        reactiveRunSpeed = (ph.reactiveRec and tonumber(ph.reactiveRec.cfg.RunSpeed)) or 20
        if not instant then info(cfg, "phase: " .. ph.name) end
    end
    applyPhase(phaseIndex, true)

    local function step(dt)
        local now = os.clock()

        -- blending into a new phase (PhaseBlendTime)
        if blend then
            local t = math.clamp((now - blend.t0) / cfg.PhaseBlendTime, 0, 1)
            local e = t * t * (3 - 2 * t)
            for _, k in ipairs(BLEND_KEYS) do
                view[k] = blend.from[k] + (blend.to[k] - blend.from[k]) * e
            end
            view.tint = blend.from.tint:Lerp(blend.to.tint, e)
            pushView()
            if t >= 1 then blend = nil end
        end

        -- walking or not: like the real skin system (Humanoid.Running speed above WalkMagnitude),
        -- or plain move input when MoveDetection = "input"
        local moving
        if cfg.MoveDetection == "input" then
            moving = humanoid.MoveDirection.Magnitude > 0
        else
            moving = runSpeed > cfg.WalkMagnitude
        end

        -- how fast you're really moving, as a speed multiplier (the main skin and each extra billboard can
        -- choose separately whether their animation follows it)
        local rawMul = 1
        if moving then
            local v = root.AssemblyLinearVelocity
            rawMul = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / 16, 0.4, 3)
        end
        local speedMul = cfg.ScaleWalkWithSpeed and rawMul or 1

        -- which frame set is playing (FrameMode can force idle or walk no matter what you do)
        local animWalk = animWalkFor(cfg.FrameMode, moving)
        if animWalk then
            walkTime += dt * speedMul
            idleTime = 0
        else
            idleTime += dt
            walkTime = 0
        end

        -- reactive sounds follow what you're really doing (not a forced FrameMode)
        updateThemes(dt, now)
        updateReactive(dt, now, moving, runSpeed)

        -- frames
        local tex, walkIdx, stepP, stepNo
        if animWalk then
            walkIdx, stepP, stepNo = walkClock(walkTime)
            tex = walk[walkIdx]
        else
            tex = idle[idleClock(idleTime)]
        end
        if tex ~= activeTexture then
            activeTexture = tex
            sprite.Image = tex
            for i = 1, #layers do layers[i].gui.Image = tex end
            setGhostFrame(tex)
        end

        -- stomps: one footstep every time the walk frame switches (same clock as the animation, so
        -- ScaleWalkWithSpeed speeds them up too). frames listed in FrameSkipStomp stay silent, and there's
        -- no sound in the air or while you're standing still. the first one plays right as you start walking
        if curStomp then
            if animWalk and moving then
                if stepNo ~= lastStomp then
                    lastStomp = stepNo
                    if not skipStomp[walkIdx] and stompFrameOk(walkIdx) and humanoid.FloorMaterial ~= Enum.Material.Air then playStomp() end
                end
            else
                lastStomp = -1
            end
        end

        -- DebugFrames: shows which walk frame is playing and which effects fire on it
        if cfg.DebugFrames then
            if animWalk and walkIdx ~= lastDebugIdx then
                lastDebugIdx = walkIdx
                local function state(enabled, skipSet)
                    if not enabled then return "off" end
                    return skipSet[walkIdx] and "SKIPPED" or "yes"
                end
                warn(("%swalk frame %d | hop: %s | jiggle: %s | stomp: %s"):format(TAG, walkIdx,
                    state(cfg.FrameJump, skipJump), state(cfg.FrameJiggle, skipJiggle),
                    state(curStomp ~= nil, skipStomp)))
            elseif not animWalk then
                lastDebugIdx = nil
            end
        end

        -- rainbow (multiplied by Tint)
        if cfg.RainbowKeyframeColor then
            local hue = (now / math.max(cfg.RainbowSpeed, 0.05)) % 1
            currentColor = mulColor(fixColor(Color3.fromHSV(hue, 1, 1), cfg), view.tint)
            sprite.ImageColor3 = currentColor
        end

        -- frame jiggle: squash toward the bottom edge right before one frame change,
        -- stretch back to normal right before the next, looping. walk frames only.
        if cfg.FrameJiggle then
            if animWalk then
                local e = stepP ^ math.max(cfg.FrameJiggleEase, 0.1)
                local amt = cfg.FrameJiggleStrength
                local target
                if stepNo % 2 == 0 then
                    target = 1 - amt * e           -- normal -> squashed
                else
                    target = 1 - amt * (1 - e)     -- squashed -> normal
                end
                -- a frame listed in FrameSkipJiggle doesn't jiggle: the sprite eases back to normal for that
                -- frame, then eases back into the cycle on the next eligible one (so it never pops).
                -- the timing is still the walk frame clock. with an empty list this is exactly the old jiggle
                local skipped = skipJiggle[walkIdx] == true
                if skipped then target = 1 end
                if skipped or jiggleEasing then
                    squashY = squashY + (target - squashY) * math.min(1, dt * 18)
                    jiggleEasing = skipped or math.abs(squashY - target) > 0.003
                else
                    squashY = target
                end
            else
                -- not walking: settle back to normal and stay there
                squashY = squashY + (1 - squashY) * math.min(1, dt * 18)
                jiggleEasing = false
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

        -- shape effects: jiggle/glitch/wobble/hover/breath/boil/jump/sway all combine here
        if transformActive then
            local k = math.min(1, dt * 10) -- smooth on/off so nothing snaps when you start/stop walking
            local wobbleTarget = (cfg.WobbleEffect and (moving or cfg.WobbleWhenIdle)) and 1 or 0
            local hoverTarget = (cfg.HoverBob and (not cfg.HoverOnlyWhenIdle or not moving)) and 1 or 0
            local breathTarget = (cfg.BreathEffect and not moving) and 1 or 0
            amp.wobble += (wobbleTarget - amp.wobble) * k
            amp.hover += (hoverTarget - amp.hover) * k
            amp.breath += (breathTarget - amp.breath) * k

            if cfg.BoilEffect and now >= nextBoil then
                nextBoil = now + 1 / math.max(cfg.BoilRate, 1)
                local bs = cfg.BoilStrength
                boil.rot = (math.random() * 2 - 1) * bs
                boil.x = (math.random() * 2 - 1) * bs * 0.004
                boil.y = (math.random() * 2 - 1) * bs * 0.004
            end

            local rot = glitch.rot + boil.rot
            if amp.wobble > 0.001 then
                rot += math.sin(now * cfg.WobbleSpeed * 6.2832) * cfg.WobbleStrength * amp.wobble
            end
            local scaleY = squashY
            if amp.breath > 0.001 then
                scaleY *= 1 + math.sin(now * cfg.BreathSpeed * 6.2832) * cfg.BreathStrength * amp.breath
            end
            hoverOffset = 0
            if amp.hover > 0.001 then
                hoverOffset = math.sin(now * cfg.HoverSpeed * 6.2832) * cfg.HoverHeight * amp.hover
            end

            -- frame jump + sway: the game's own animation (see stepBounce). the hop is a WORLD-space vertical offset
            -- (StudsOffsetWorldSpace) driven by each frame's own duration, so it always lands back on the original
            -- position. frames listed in FrameSkipJump don't hop
            if cfg.FrameJump or cfg.FrameSwayAmount ~= 0 then
                local h, r = stepBounce(bounce, cfg.FrameBounceStyle, animWalk, walkIdx, stepP, stepNo,
                    cfg.FrameJump and cfg.FrameJumpHighestHeight or 0, cfg.FrameSwayAmount, skipJump, dt)
                jumpOffset = h
                if cfg.FrameJump then gui.StudsOffsetWorldSpace = Vector3.new(0, jumpOffset, 0) end
                rot += r
            end

            holder.Rotation = rot
            holder.Size = UDim2.new(glitch.scale, 0, glitch.scale * scaleY, 0)
            holder.Position = UDim2.new(0.5 + boil.x, 0, 1 + boil.y, 0)
            gui.StudsOffset = Vector3.new(view.ox + glitch.x, view.oy + glitch.y + hoverOffset, view.oz + glitch.z)
        end

        -- visibility effects: ghost pulse / flicker combine into one transparency
        local visNow = 1
        if alphaActive then
            local vis = 1
            if cfg.GhostPulse then
                local wave = (math.sin(now * cfg.GhostPulseSpeed * 6.2832) + 1) / 2
                vis *= cfg.GhostPulseMin + (1 - cfg.GhostPulseMin) * wave
            end
            if cfg.FlickerEffect then
                if now >= flickerUntil and math.random() < cfg.FlickerRate * dt then
                    flickerUntil = now + cfg.FlickerDuration * (0.5 + math.random())
                end
                if now < flickerUntil then
                    vis *= 1 - math.clamp(cfg.FlickerDepth, 0, 1)
                end
            end
            visNow = vis
            local tr = 1 - (1 - view.transparency) * vis
            if math.abs(tr - lastAlpha) > 0.002 then
                lastAlpha = tr
                sprite.ImageTransparency = tr
            end
        end

        -- billboard layers follow ghost pulse / flicker
        if #layers > 0 and alphaActive then
            for i = 1, #layers do
                local l = layers[i]
                l.gui.ImageTransparency = 1 - (1 - l.base) * visNow
            end
        end

        -- horizontal slicing: mirror the sprite onto the strips and slide random strips left and right
        if #strips > 0 then
            local simg, scol, str = sprite.Image, sprite.ImageColor3, sprite.ImageTransparency
            if simg ~= stripImage then
                stripImage = simg
                layoutStrips(simg)
            end
            if now >= sliceNextRoll then
                sliceNextRoll = now + cfg.SliceRerollTime
                for i = 1, #strips do
                    local st = strips[i]
                    st.ampTarget = (math.random() < cfg.SliceChance) and (0.3 + 0.7 * math.random()) * cfg.SliceStrength or 0
                    st.gap = cfg.SliceGapChance > 0 and math.random() < cfg.SliceGapChance
                end
            end
            local ease = math.min(1, dt * 8)
            for i = 1, #strips do
                local st = strips[i]
                st.amp += (st.ampTarget - st.amp) * ease
                local off = st.amp * math.sin(now * cfg.SliceSpeed * 6.2832 * st.freq + st.phase)
                local img = st.img
                if img.Image ~= simg then img.Image = simg end
                if img.ImageColor3 ~= scol then img.ImageColor3 = scol end
                local tr = (st.gap and st.amp > 0.02) and 1 or str
                if img.ImageTransparency ~= tr then img.ImageTransparency = tr end
                if sliceMode == "rect" then
                    img.Position = UDim2.new(off, 0, st.y0 or 0, 0)
                else
                    img.Position = UDim2.new((off + sliceMargin) / (1 + 2 * sliceMargin), 0, -(i - 1), 0)
                end
            end
        end

        -- extra billboards
        for i = 1, #extras do updateExtra(extras[i], dt, moving, rawMul) end

        -- orbs move in their pattern (circle / figure8 / spiral / flower / snake)
        if #orbs > 0 then
            local center = root.Position
            if fieldVisual then fieldVisual.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)) end
            if usesSnake then
                local last = pathHist[#pathHist]
                if not last or now - last.t >= 0.03 then
                    pathHist[#pathHist + 1] = {t = now, p = center}
                end
                while pathHist[1] and pathHist[1].t < now - maxSnakeDelay - 0.5 do
                    table.remove(pathHist, 1)
                end
            end
            for i = 1, #orbs do
                local o = orbs[i]
                local sp = o.spec
                local a = o.phase + now * sp.Speed * 6.2832
                local bob = 0
                if sp.Bob ~= 0 then bob = math.sin(now * sp.BobSpeed * 6.2832 + o.phase) * sp.Bob end
                if sp.Pattern == "snake" then
                    -- a small swirl keeps them from stacking on top of each other when you stand still
                    local swirl = Vector3.new(math.cos(a), 0, math.sin(a)) * math.min(1.2, sp.Distance)
                    local p = pathAt(now - o.spec.index * (sp.SnakeSpacing or 0.3))
                    local rel = (p + swirl) - center -- where it wants to be, relative to you
                    rel = applyField(o, sp, rel, rel.Y + sp.Height + bob, dt)
                    o.part.CFrame = CFrame.new(center + rel + Vector3.new(0, sp.Height + bob, 0))
                else
                    local offset = orbOffset(sp, a)
                    if sp.Tilt ~= 0 then
                        offset = CFrame.Angles(math.rad(sp.Tilt), 0, 0):VectorToWorldSpace(offset)
                    end
                    if sp.Wobble ~= 0 then -- the ring slowly rocks (tips about the forward axis), like the game's orbs
                        local w = math.rad(sp.Wobble) * math.sin(now * sp.WobbleSpeed * 6.2832)
                        offset = CFrame.Angles(0, 0, w):VectorToWorldSpace(offset)
                    end
                    offset = applyField(o, sp, offset, offset.Y + sp.Height + bob, dt)
                    o.part.CFrame = CFrame.new(center + offset + Vector3.new(0, sp.Height + bob, 0))
                end
                if o.fires then
                    -- fractional FireRate: this Fire is only switched on for part of every 0.08s cycle
                    local cycle = ((now + o.phase) % 0.08) / 0.08
                    for j = 1, #o.fires do
                        local f = o.fires[j]
                        local on = cycle < f.duty
                        if f.fire.Enabled ~= on then f.fire.Enabled = on end
                    end
                end
                if o.frames and #o.frames > 1 then
                    o.img.Image = o.frames[math.floor(now / math.max(sp.ImageFrameSpeed, 0.02)) % #o.frames + 1]
                end
            end
        end

        -- afterimages
        if cfg.AfterimageEffect and not scareHideGhosts then
            local rate = cfg.AfterimageRate
            if now - lastTrail >= rate then
                lastTrail = now
                spawnAfterimage(activeTexture, moving)
            end
        end

        -- point light: keep your values applied (some games reset their lights)
        if lightRef and pl then
            if pl.FollowSkinColor then
                lightRef.Color = currentColor
            elseif plColor and lightRef.Color ~= plColor then
                lightRef.Color = plColor
            end
            if pl.Brightness and lightRef.Brightness ~= pl.Brightness then lightRef.Brightness = pl.Brightness end
            if pl.Range and lightRef.Range ~= pl.Range then lightRef.Range = pl.Range end
            if not lightRef.Enabled then lightRef.Enabled = true end
        end

        -- hide the real character
        for i = 1, #hiddenParts do
            hiddenParts[i].LocalTransparencyModifier = 1
        end
    end

    -- errors are caught so one bad frame can't spam the console or kill the skin
    local errored = false
    conns[#conns + 1] = RunService.RenderStepped:Connect(function(dt)
        local ok, err = pcall(step, dt)
        if not ok and not errored then
            errored = true
            warn(TAG .. "render error (send this to the dev): " .. tostring(err))
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
        if oldDisplayType then
            pcall(function() humanoid.DisplayDistanceType = oldDisplayType end)
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
        if orbHolder then orbHolder:Destroy() end
        for _, e in ipairs(extras) do e.gui:Destroy() end
        for _, sc in ipairs(scares) do
            if sc.gui then sc.gui:Destroy() end
        end
        wipeDownloads()
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