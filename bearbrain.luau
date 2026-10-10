-- SkinBrain v2.8
-- the boring work: downloads/caching, frame logic, billboard, effects, cleanup.
-- you never need to edit this. all settings live in SkinTemplate.lua.
-- host it (github raw link) or put it in your executor's workspace as "SkinBrain.lua".

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local env = (getgenv and getgenv()) or _G
local TAG = "[SkinBrain] "
local Brain = {Version = "2.8"}

-- --- DEFAULTS ---
local DEFAULTS = {
    SkinName = "Skin",

    -- sprites (rbxassetid / number / link). lists, any amount of frames
    Idle = {},
    Walk = {},
    IdleFrameSwitchSpeed = 0.25,   -- seconds per idle frame
    IdleFrameCycle = false,
    WalkFrameCycle = false,
    ScaleWalkWithSpeed = false,    -- walk animation speeds up/slows down with your real speed

    -- billboard
    sizeX = 7,
    sizeY = 7,
    studsOffsetY = 0.25,
    Tint = Color3.new(1, 1, 1),
    Transparency = 0,
    LightInfluence = 1,
    AlwaysOnTop = false,
    PixelArt = false,              -- crisp pixels instead of smoothed
    HideCharacter = false,
    HideNameTag = false,
    RemoveOtherBillboards = true,

    -- effects
    FrameJiggle = false,
    FrameJiggleStrength = 0.03,    -- how much it squashes (0.12 = down to 88% height)
    FrameJiggleEase = 1.5,           -- 1 = even squash across the frame, higher = snaps right before the change
    FrameSkipJiggle = {},          -- walk frame numbers (1 = first walk sprite) that do NOT trigger the jiggle. empty = none skipped

    FrameJump = false,             -- a little visual hop on every walk frame (only the sprite moves, NOT a real jump)
    FrameJumpHighestHeight = 1,    -- how high each hop goes, in studs
    FrameSkipJump = {},            -- walk frame numbers (1 = first walk sprite) that do NOT hop. empty = none skipped

    GlitchEffect = false,
    GlitchStrength = 0.4,
    GlitchRate = 20,

    RainbowKeyframeColor = false,
    RainbowSpeed = 10,

    AfterimageEffect = false,
    AfterimageRate = 0.15,         -- seconds between ghosts
    AfterimageMax = 40,
    AfterimageFadeTime = 0.5,      -- particle lifetime in seconds (TBB's emitter uses 0.5)
    AfterimageTransparency = 0.4,
    AfterimageDistort = true,
    AfterimageSizeScale = 0.5,     -- multiplies the size of each ghost
    AfterimageGrow = 0,            -- 0 = ghosts keep their size and just fade out. 0.2 = they grow 20% by the end
    AfterimageLightEmission = 0.5, -- 0 = normal, 1 = glowing/additive (great with rainbow)
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
}
-- settings that are allowed to be nil (so they aren't flagged as typos)
local OPTIONAL = {WalkFrameSwitchSpeed = true, ThemeSound = true, PointLightModifier = true,
    VoiceLines = true, StompSound = true, OrbOrbit = true}

-- scales a color's saturation/brightness (see ColorSaturation / ColorBrightness)
local function fixColor(c, cfg)
    if typeof(c) ~= "Color3" then return c end
    local sat, bri = cfg.ColorSaturation or 1, cfg.ColorBrightness or 1
    if sat == 1 and bri == 1 then return c end
    local h, sv, v = c:ToHSV()
    return Color3.fromHSV(h, math.clamp(sv * sat, 0, 1), math.clamp(v * bri, 0, 1))
end

local function buildConfig(user)
    local cfg = {}
    for k, v in pairs(user or {}) do
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
    cfg.ColorSaturation = math.max(cfg.ColorSaturation, 0)
    cfg.ColorBrightness = math.max(cfg.ColorBrightness, 0)
    cfg.Tint = fixColor(cfg.Tint, cfg)
    cfg.ShadowColor = fixColor(cfg.ShadowColor, cfg)
    if cfg.WalkFrameSwitchSpeed ~= nil and type(cfg.WalkFrameSwitchSpeed) ~= "number" then
        warn(TAG .. "WalkFrameSwitchSpeed should be a number or nil, using the default")
        cfg.WalkFrameSwitchSpeed = nil
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
    ["Accept"] = "image/png,image/jpeg,audio/mpeg,audio/ogg,*/*;q=0.5",
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

    if not cfg.ForceRedownload then
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
            elseif isLink(src) then
                pending += 1
                task.spawn(function()
                    local assets, files = fetch(src, e.kind, cfg)
                    out[src] = assets or false
                    if assets and files then
                        for _, p in ipairs(files) do paths[#paths + 1] = p end
                    end
                    pending -= 1
                end)
            else
                warn(TAG .. "can't use '" .. src .. "' (use rbxassetid://..., a number, or an http(s) link)")
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

-- frame picker. cycle = ping-pong (1,2,3,2,1,2,3...) so no frame ever shows twice in a row
local function pickFrame(frames, t, speed, cycle)
    local n = #frames
    if n == 1 then return frames[1], 1 end
    local step = math.floor(t / math.max(speed, 0.01))
    local idx
    if cycle and n > 2 then
        local period = 2 * n - 2
        local p = step % period
        idx = (p < n) and (p + 1) or (period - p + 1)
    else
        idx = (step % n) + 1
    end
    return frames[idx], idx -- the picked sprite, and its number in the list (1 = first)
end

local function mulColor(a, b)
    return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
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
    local theme = cfg.ThemeSound
    local themeSrc = type(theme) == "table" and normalize(theme.Id) or nil
    if themeSrc then entries[#entries + 1] = {src = themeSrc, kind = "audio"} end

    -- voice lines + stomp sounds: only downloaded when enabled
    local voiceCfg = type(cfg.VoiceLines) == "table" and cfg.VoiceLines or nil
    local stompCfg = type(cfg.StompSound) == "table" and cfg.StompSound or nil
    local voiceSrc = (voiceCfg and voiceCfg.Enabled) and collect(voiceCfg.Sounds, "audio") or {}
    local stompSrc = (stompCfg and stompCfg.Enabled) and collect(stompCfg.Sounds, "audio") or {}

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
            ImageFrameSpeed = 0.1,                   -- seconds per frame for gif/multi-frame image orbs
        }
        for k, v in pairs(orbCfg) do
            if k ~= "Enabled" and k ~= "Orbs" and k ~= "Count" then shared[k] = v end
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
            spec.Color = fixColor(spec.Color, cfg)
            if spec.SecondaryColor then spec.SecondaryColor = fixColor(spec.SecondaryColor, cfg) end
            if spec.ImageColor then spec.ImageColor = fixColor(spec.ImageColor, cfg) end
            spec.phase = spec.Phase and math.rad(spec.Phase) or ((i - 1) / n * math.pi * 2)
            if spec.Type == "image" then spec.imageSrc = collect(spec.Image, "image") end
            if spec.Texture then spec.textureSrc = collect(spec.Texture, "image") end
            orbSpecs[#orbSpecs + 1] = spec
        end
    end

    local resolved, downloadedPaths = resolveAll(entries, cfg)

    -- deletes the files this run downloaded/used (only if DeleteDownloadsOnRemove is on)
    local function wipeDownloads()
        if cfg.DeleteDownloadsOnRemove and delfile then
            for _, p in ipairs(downloadedPaths) do pcall(delfile, p) end
        end
    end

    local function frames(srcList)
        local out = {}
        for _, s in ipairs(srcList) do
            local r = resolved[s]
            if r then
                for _, a in ipairs(r) do out[#out + 1] = a end
            end
        end
        return out
    end
    local idle, walk = frames(idleSrc), frames(walkSrc)
    if #idle == 0 and #walk > 0 then idle = {walk[1]} end
    if #walk == 0 then walk = idle end
    for _, spec in ipairs(orbSpecs) do
        spec.frames = spec.imageSrc and frames(spec.imageSrc) or {}
        spec.texture = spec.textureSrc and frames(spec.textureSrc)[1] or nil
    end
    info(cfg, ("loaded '%s': %d idle frame(s), %d walk frame(s)"):format(
        cfg.SkinName, #frames(idleSrc), #frames(walkSrc)))
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
    gui.Size = UDim2.new(cfg.sizeX, 0, cfg.sizeY, 0)
    gui.StudsOffset = Vector3.new(0, cfg.studsOffsetY, 0)
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
    sprite.ImageColor3 = cfg.Tint
    sprite.ImageTransparency = cfg.Transparency
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
    local currentColor = cfg.Tint
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
        local aspect = cfg.sizeY / math.max(cfg.sizeX, 0.01)
        local squash = (aspect - 1) / (aspect + 1)
        local baseSize = cfg.sizeX / math.max(1 - squash, 0.013) * cfg.AfterimageSizeScale
        local endSize = baseSize * (1 + cfg.AfterimageGrow) -- default: same size the whole time, it only fades
        local sizeEnv = cfg.AfterimageDistort and baseSize * 0.015 or 0
        local squashEnv = cfg.AfterimageDistort and 0.01 or 0

        for _, set in ipairs({idle, walk}) do
            for _, id in ipairs(set) do
                if not emitters[id] then
                    local em = Instance.new("ParticleEmitter")
                    em.Texture = id
                    em.Rate = 0 -- we emit by hand
                    em.Enabled = true
                    em.Speed = NumberRange.new(0)
                    em.SpreadAngle = Vector2.new(0, 0)
                    em.Acceleration = Vector3.new(0, 0, 0)
                    em.Drag = 0
                    em.Rotation = NumberRange.new(0)
                    em.RotSpeed = NumberRange.new(0)
                    em.LockedToPart = false -- ghosts stay where they were emitted
                    em.Orientation = Enum.ParticleOrientation.FacingCamera
                    em.LightEmission = cfg.AfterimageLightEmission
                    em.LightInfluence = cfg.LightInfluence
                    em.ZOffset = cfg.AfterimageZOffset -- layering by render depth, no physical offset
                    em.Lifetime = NumberRange.new(cfg.AfterimageFadeTime, cfg.AfterimageFadeTime)
                    em.Color = ColorSequence.new(currentColor)
                    em.Transparency = NumberSequence.new(cfg.AfterimageTransparency, 1)
                    em.Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, baseSize, sizeEnv),
                        NumberSequenceKeypoint.new(1, endSize, sizeEnv),
                    })
                    em.Squash = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, squash, squashEnv),
                        NumberSequenceKeypoint.new(1, squash, squashEnv),
                    })
                    em.Parent = attach
                    emitters[id] = em
                end
            end
        end
    end

    local function spawnAfterimage(texture, moving)
        local em = emitters[texture]
        if not em then return end

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
        local up = Vector3.new(0, cfg.studsOffsetY + hoverOffset + jumpOffset, 0)
        trailPart.CFrame = CFrame.new(root.Position + (cam and cam.CFrame:VectorToWorldSpace(up) or up))

        if cfg.RainbowKeyframeColor then em.Color = ColorSequence.new(currentColor) end
        em:Emit(1)
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

    -- theme sound (optional)
    if themeSrc and resolved[themeSrc] then
        local s = Instance.new("Sound")
        s.Name = "SkinBrainTheme"
        s.SoundId = resolved[themeSrc][1]
        s.Volume = theme.Volume or 1
        s.Looped = true -- always loops until you reset/respawn
        s.PlaybackSpeed = theme.PlaybackSpeed or 1
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

    -- voice lines (optional): one random line every MinDelay..MaxDelay seconds.
    -- lines never overlap (it waits for the current one to finish) and never loop
    local voiceAssets = frames(voiceSrc)
    if voiceCfg and voiceCfg.Enabled and #voiceAssets > 0 then
        local voiceSounds = {}
        for i, id in ipairs(voiceAssets) do
            local vs = Instance.new("Sound")
            vs.Name = "SkinBrainVoice" .. i
            vs.SoundId = id
            vs.Volume = voiceCfg.Volume or 1
            vs.Looped = false
            if voiceCfg.RollOffMaxDistance then vs.RollOffMaxDistance = voiceCfg.RollOffMaxDistance end
            vs.Parent = root
            sounds[#sounds + 1] = vs
            voiceSounds[i] = vs
        end

        task.spawn(function()
            local minD = math.max(voiceCfg.MinDelay or 23, 0)
            local maxD = math.max(voiceCfg.MaxDelay or 34, minD)
            local lastPick
            local nextAt = os.clock() + minD + math.random() * (maxD - minD)
            while alive do
                while alive and os.clock() < nextAt do task.wait(0.25) end
                if not alive then break end

                -- random line, but not the same one twice in a row
                local pick = math.random(#voiceSounds)
                if #voiceSounds > 1 and pick == lastPick then pick = pick % #voiceSounds + 1 end
                lastPick = pick

                local vs = voiceSounds[pick]
                local startedAt = os.clock()
                local finished = false
                vs.TimePosition = 0
                vs.Ended:Once(function() finished = true end)
                vs:Play()
                -- wait for it to end (with a timeout in case the sound never loads)
                while alive and not finished and os.clock() - startedAt < 90 do task.wait(0.1) end

                -- next line is timed from when this one started, but never before this one ended
                nextAt = math.max(os.clock(), startedAt + minD + math.random() * (maxD - minD))
            end
        end)
    end

    -- stomp sounds (optional): a random footstep each time the walk frame switches
    local stompAssets = frames(stompSrc)
    local stompSounds, lastStomp, lastStompPick = {}, -1, nil
    if stompCfg and stompCfg.Enabled and #stompAssets > 0 then
        for i, id in ipairs(stompAssets) do
            local ss = Instance.new("Sound")
            ss.Name = "SkinBrainStomp" .. i
            ss.SoundId = id
            ss.Volume = stompCfg.Volume or 0.8
            ss.Looped = false
            if stompCfg.RollOffMaxDistance then ss.RollOffMaxDistance = stompCfg.RollOffMaxDistance end
            ss.Parent = root
            sounds[#sounds + 1] = ss
            stompSounds[i] = ss
        end
    end

    local function playStomp()
        local n = #stompSounds
        local pick = math.random(n)
        if n > 1 and pick == lastStompPick then pick = pick % n + 1 end -- no same footstep twice in a row
        lastStompPick = pick
        local ss = stompSounds[pick]
        local variation = stompCfg.PitchVariation or 0.08
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
    local orbHolder
    local orbs = {}
    if #orbSpecs > 0 then
        orbHolder = Instance.new("Folder")
        orbHolder.Name = "SkinBrainOrbs"
        orbHolder.Parent = workspace

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

    -- main loop
    local walkSpeed = cfg.WalkFrameSwitchSpeed or 0.125 -- 0.125 == math.floor(walkTime * 8) % 2
    local walkTime, idleTime = 0, 0
    local activeTexture = idle[1]
    local squashY = 1
    local glitch = {x = 0, y = 0, z = 0, rot = 0, scale = 1}
    local nextGlitch, lastTrail = 0, 0

    local transformActive = cfg.FrameJiggle or cfg.GlitchEffect or cfg.WobbleEffect
        or cfg.HoverBob or cfg.BreathEffect or cfg.BoilEffect or cfg.FrameJump
    local alphaActive = cfg.GhostPulse or cfg.FlickerEffect
    local amp = {wobble = 0, hover = 0, breath = 0}
    local boil = {rot = 0, x = 0, y = 0}
    local nextBoil, flickerUntil, lastAlpha = 0, 0, -1

    -- FrameSkipJump / FrameSkipJiggle: walk frame numbers to leave out. bad or empty lists skip nothing
    local skipJump = toIndexSet(cfg.FrameSkipJump, "FrameSkipJump")
    local skipJiggle = toIndexSet(cfg.FrameSkipJiggle, "FrameSkipJiggle")
    local jumpY = 0
    local jiggleEasing = false

    local function step(dt)
        local now = os.clock()
        local moving = humanoid.MoveDirection.Magnitude > 0

        if moving then
            local mul = 1
            if cfg.ScaleWalkWithSpeed then
                local v = root.AssemblyLinearVelocity
                local flat = Vector3.new(v.X, 0, v.Z).Magnitude
                mul = math.clamp(flat / 16, 0.4, 3)
            end
            walkTime += dt * mul
            idleTime = 0
        else
            idleTime += dt
            walkTime = 0
        end

        -- stomps: one footstep every time the walk frame switches (same timer as the animation,
        -- so ScaleWalkWithSpeed speeds them up too). none while you're in the air.
        -- the first one plays right as you start walking
        if #stompSounds > 0 then
            if moving then
                local walkStep = math.floor(walkTime / math.max(walkSpeed, 0.01))
                if walkStep ~= lastStomp then
                    lastStomp = walkStep
                    if humanoid.FloorMaterial ~= Enum.Material.Air then playStomp() end
                end
            else
                lastStomp = -1
            end
        end

        -- frames
        local tex, walkIdx
        if moving then
            tex, walkIdx = pickFrame(walk, walkTime, walkSpeed, cfg.WalkFrameCycle)
        else
            tex = pickFrame(idle, idleTime, cfg.IdleFrameSwitchSpeed, cfg.IdleFrameCycle)
        end
        if tex ~= activeTexture then
            activeTexture = tex
            sprite.Image = tex
            for i = 1, #layers do layers[i].gui.Image = tex end
        end

        -- rainbow (multiplied by Tint)
        if cfg.RainbowKeyframeColor then
            local hue = (now / math.max(cfg.RainbowSpeed, 0.05)) % 1
            currentColor = mulColor(fixColor(Color3.fromHSV(hue, 1, 1), cfg), cfg.Tint)
            sprite.ImageColor3 = currentColor
        end

        -- frame jiggle: squash toward the bottom edge right before one frame change,
        -- stretch back to normal right before the next, looping. walking only.
        if cfg.FrameJiggle then
            if moving then
                local stepF = walkTime / math.max(walkSpeed, 0.01)
                local whole = math.floor(stepF)
                local e = (stepF - whole) ^ math.max(cfg.FrameJiggleEase, 0.1)
                local amt = cfg.FrameJiggleStrength
                local target
                if whole % 2 == 0 then
                    target = 1 - amt * e           -- normal -> squashed
                else
                    target = 1 - amt * (1 - e)     -- squashed -> normal
                end
                -- a frame listed in FrameSkipJiggle doesn't jiggle: the sprite eases back to normal for that
                -- frame, then eases back into the cycle on the next eligible one (so it never pops).
                -- the timing is still the walk frame timer. with an empty list this is exactly the old jiggle
                local skipped = skipJiggle[walkIdx] == true
                if skipped then target = 1 end
                if skipped or jiggleEasing then
                    squashY = squashY + (target - squashY) * math.min(1, dt * 18)
                    jiggleEasing = skipped or math.abs(squashY - target) > 0.003
                else
                    squashY = target
                end
            else
                -- stopped walking: settle back to normal and stay there
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

        -- shape effects: jiggle/glitch/wobble/hover/breath/boil all combine here
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

            -- frame jump: every walk frame that isn't in FrameSkipJump gets one smooth hop (a parabola that
            -- starts and ends at 0 across that frame's time slot), so hops follow the walk frame speed
            -- exactly and always land back on the original position before the next one.
            -- it's recomputed from the walk timer every frame (never accumulated) and only moves the sprite
            if cfg.FrameJump then
                if moving then
                    local target = 0
                    if not skipJump[walkIdx] then
                        local stepF = walkTime / math.max(walkSpeed, 0.01)
                        local p = stepF - math.floor(stepF)
                        target = cfg.FrameJumpHighestHeight * 4 * p * (1 - p)
                    end
                    jumpY = target
                else
                    -- stopped walking: settle back to the original position
                    jumpY = jumpY * (1 - math.min(1, dt * 18))
                    if jumpY < 0.001 then jumpY = 0 end
                end
                jumpOffset = jumpY
            end

            holder.Rotation = rot
            holder.Size = UDim2.new(glitch.scale, 0, glitch.scale * scaleY, 0)
            holder.Position = UDim2.new(0.5 + boil.x, 0, 1 + boil.y, 0)
            gui.StudsOffset = Vector3.new(glitch.x, cfg.studsOffsetY + glitch.y + hoverOffset + jumpOffset, glitch.z)
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
            local tr = 1 - (1 - cfg.Transparency) * vis
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

        -- orbs circle you (world axes, so they don't turn when you turn)
        if #orbs > 0 then
            local center = root.Position
            for i = 1, #orbs do
                local o = orbs[i]
                local sp = o.spec
                local a = o.phase + now * sp.Speed * 6.2832
                local offset = Vector3.new(math.cos(a) * sp.Distance, 0, math.sin(a) * sp.Distance)
                if sp.Tilt ~= 0 then
                    offset = CFrame.Angles(math.rad(sp.Tilt), 0, 0):VectorToWorldSpace(offset)
                end
                local bob = 0
                if sp.Bob ~= 0 then bob = math.sin(now * sp.BobSpeed * 6.2832 + o.phase) * sp.Bob end
                o.part.CFrame = CFrame.new(center + offset + Vector3.new(0, sp.Height + bob, 0))
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
        if cfg.AfterimageEffect then
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
