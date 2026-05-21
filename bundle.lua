-- BeatForge v1.0.0  —  single-file bundle
-- Drop this file in your map folder and: local bf = require('beatforge')

-- ── Module registry ──────────────────────────────────────────────────────────
local _BF_MODULES = {}
local function _bf_require(name)
    if _BF_MODULES[name] then return _BF_MODULES[name] end
    error('BeatForge internal: unknown module ' .. tostring(name))
end

-- ── Module: json ────────────────────────────────────────────────────────
_BF_MODULES["json"] = (function()

    local json = {}

    -- ─── Decode ──────────────────────────────────────────────────────────────────

    local function skipWhitespace(s, pos)
        return s:match("^%s*()", pos)
    end

    local function parseValue(s, pos)  -- forward declaration
    end

    local function parseString(s, pos)
        -- pos is at opening '"'
        local result = {}
        local i = pos + 1
        while i <= #s do
            local c = s:sub(i, i)
            if c == '"' then
                return table.concat(result), i + 1
            elseif c == '\\' then
                local esc = s:sub(i+1, i+1)
                if esc == '"'  then table.insert(result, '"')
                elseif esc == '\\' then table.insert(result, '\\')
                elseif esc == '/'  then table.insert(result, '/')
                elseif esc == 'n'  then table.insert(result, '\n')
                elseif esc == 'r'  then table.insert(result, '\r')
                elseif esc == 't'  then table.insert(result, '\t')
                elseif esc == 'b'  then table.insert(result, '\b')
                elseif esc == 'f'  then table.insert(result, '\f')
                elseif esc == 'u'  then
                    local hex = s:sub(i+2, i+5)
                    local cp  = tonumber(hex, 16) or 0
                    if cp < 0x80 then
                        table.insert(result, string.char(cp))
                    elseif cp < 0x800 then
                        table.insert(result, string.char(0xC0 + math.floor(cp/64), 0x80 + cp%64))
                    else
                        table.insert(result, string.char(
                            0xE0 + math.floor(cp/4096),
                            0x80 + math.floor(cp/64)%64,
                            0x80 + cp%64))
                    end
                    i = i + 4
                end
                i = i + 2
            else
                table.insert(result, c)
                i = i + 1
            end
        end
        error("JSON: unterminated string near position " .. pos)
    end

    local function parseArray(s, pos)
        local arr = {}
        pos = skipWhitespace(s, pos + 1)
        if s:sub(pos, pos) == ']' then return arr, pos + 1 end
        while true do
            local val
            val, pos = parseValue(s, pos)
            table.insert(arr, val)
            pos = skipWhitespace(s, pos)
            local c = s:sub(pos, pos)
            if c == ']' then return arr, pos + 1 end
            if c ~= ',' then error("JSON: expected ',' or ']' at position " .. pos) end
            pos = skipWhitespace(s, pos + 1)
        end
    end

    local function parseObject(s, pos)
        local obj = {}
        pos = skipWhitespace(s, pos + 1)
        if s:sub(pos, pos) == '}' then return obj, pos + 1 end
        while true do
            if s:sub(pos, pos) ~= '"' then
                error("JSON: expected string key at position " .. pos)
            end
            local key
            key, pos = parseString(s, pos)
            pos = skipWhitespace(s, pos)
            if s:sub(pos, pos) ~= ':' then
                error("JSON: expected ':' at position " .. pos)
            end
            pos = skipWhitespace(s, pos + 1)
            local val
            val, pos = parseValue(s, pos)
            obj[key] = val
            pos = skipWhitespace(s, pos)
            local c = s:sub(pos, pos)
            if c == '}' then return obj, pos + 1 end
            if c ~= ',' then error("JSON: expected ',' or '}' at position " .. pos) end
            pos = skipWhitespace(s, pos + 1)
        end
    end

    parseValue = function(s, pos)
        pos = skipWhitespace(s, pos)
        local c = s:sub(pos, pos)
        if c == '"' then
            return parseString(s, pos)
        elseif c == '{' then
            return parseObject(s, pos)
        elseif c == '[' then
            return parseArray(s, pos)
        elseif c == 't' then
            assert(s:sub(pos, pos+3) == "true"); return true, pos + 4
        elseif c == 'f' then
            assert(s:sub(pos, pos+4) == "false"); return false, pos + 5
        elseif c == 'n' then
            assert(s:sub(pos, pos+3) == "null"); return nil, pos + 4  -- becomes nil key gap
        else
            local num, next = s:match("^(-?%d+%.?%d*[eE]?[+-]?%d*)()", pos)
            if num then return tonumber(num), next end
            error("JSON: unexpected character '" .. c .. "' at position " .. pos)
        end
    end

    --- Decode a JSON string into a Lua value.
    --- @param s string
    --- @return any
    function json.decode(s)
        local val, _ = parseValue(s, 1)
        return val
    end

    -- ─── Encode ──────────────────────────────────────────────────────────────────

    local ESC = {
        ['"']  = '\\"',
        ['\\'] = '\\\\',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t',
        ['\b'] = '\\b',
        ['\f'] = '\\f',
    }

    local function encodeString(s)
        return '"' .. s:gsub('[%z\1-\31"\\]', function(c)
            return ESC[c] or string.format("\\u%04x", c:byte())
        end) .. '"'
    end

    local function isArray(t)
        -- A table is an array when all keys are consecutive integers from 1
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        for i = 1, n do
            if t[i] == nil then return false end
        end
        return n > 0 or next(t) == nil
    end

    local function encodeValue(v, indent, indentStr)
        local ty = type(v)
        if ty == "nil"     then return "null"
        elseif ty == "boolean" then return tostring(v)
        elseif ty == "number"  then
            if v ~= v then return "null" end      -- NaN guard
            if v == math.huge or v == -math.huge then return "null" end
            -- Omit trailing .0 for integers
            if math.floor(v) == v and math.abs(v) < 1e15 then
                return string.format("%d", v)
            end
            return string.format("%.10g", v)
        elseif ty == "string" then
            return encodeString(v)
        elseif ty == "table"  then
            if isArray(v) then
                local parts = {}
                for _, item in ipairs(v) do
                    table.insert(parts, encodeValue(item, indent, indentStr))
                end
                return "[" .. table.concat(parts, ",") .. "]"
            else
                local parts = {}
                -- Sort keys for deterministic output
                local keys = {}
                for k in pairs(v) do table.insert(keys, k) end
                table.sort(keys, function(a, b)
                    return tostring(a) < tostring(b)
                end)
                for _, k in ipairs(keys) do
                    local encoded = encodeValue(v[k], indent, indentStr)
                    if encoded ~= "null" or v[k] ~= nil then
                        table.insert(parts, encodeString(tostring(k)) .. ":" .. encoded)
                    end
                end
                return "{" .. table.concat(parts, ",") .. "}"
            end
        else
            return "null"
        end
    end

    --- Encode a Lua value to a JSON string.
    --- @param v any
    --- @return string
    function json.encode(v)
        return encodeValue(v, 0, "  ")
    end

    return json
end)()

-- ── Module: bfmath ──────────────────────────────────────────────────────
_BF_MODULES["bfmath"] = (function()

    local bfmath = {}

    -- ─── Scalar ──────────────────────────────────────────────────────────────────

    function bfmath.lerp(a, b, t)    return a + (b - a) * t end
    function bfmath.clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
    function bfmath.map(v, i0, i1, o0, o1)
        return o0 + (o1 - o0) * ((v - i0) / (i1 - i0))
    end
    function bfmath.round(v, places)
        local f = 10 ^ (places or 0)
        return math.floor(v * f + 0.5) / f
    end

    -- ─── Vector (tables of n numbers) ────────────────────────────────────────────

    function bfmath.vecLerp(a, b, t)
        local r = {}
        for i = 1, #a do r[i] = a[i] + (b[i] - a[i]) * t end
        return r
    end

    function bfmath.vecAdd(a, b)
        local r = {}
        for i = 1, #a do r[i] = a[i] + b[i] end
        return r
    end

    function bfmath.vecScale(a, s)
        local r = {}
        for i = 1, #a do r[i] = a[i] * s end
        return r
    end

    --- Dot product (for equal-length vectors)
    function bfmath.dot(a, b)
        local s = 0
        for i = 1, #a do s = s + a[i] * b[i] end
        return s
    end

    --- 3-component cross product
    function bfmath.cross(a, b)
        return {
            a[2]*b[3] - a[3]*b[2],
            a[3]*b[1] - a[1]*b[3],
            a[1]*b[2] - a[2]*b[1],
        }
    end

    -- ─── Easing functions ─────────────────────────────────────────────────────────
    -- All accept t in [0,1] and return a value in [0,1].

    local pi = math.pi
    local function sq(x) return x * x end
    local function cb(x) return x * x * x end

    bfmath.ease = {
        linear      = function(t) return t end,
        inSine      = function(t) return 1 - math.cos(t * pi * 0.5) end,
        outSine     = function(t) return math.sin(t * pi * 0.5) end,
        inOutSine   = function(t) return -(math.cos(pi * t) - 1) / 2 end,
        inQuad      = function(t) return sq(t) end,
        outQuad     = function(t) return 1 - sq(1 - t) end,
        inOutQuad   = function(t)
                        return t < 0.5 and 2*sq(t) or 1 - sq(-2*t+2)/2
                      end,
        inCubic     = function(t) return cb(t) end,
        outCubic    = function(t) return 1 - cb(1 - t) end,
        inOutCubic  = function(t)
                        return t < 0.5 and 4*cb(t) or 1 - cb(-2*t+2)/2
                      end,
        inExpo      = function(t) return t == 0 and 0 or 2^(10*t - 10) end,
        outExpo     = function(t) return t == 1 and 1 or 1 - 2^(-10*t) end,
        inOutExpo   = function(t)
                        if t == 0 then return 0 end
                        if t == 1 then return 1 end
                        if t < 0.5 then return 2^(20*t-10)/2 end
                        return (2 - 2^(-20*t+10))/2
                      end,
        inElastic   = function(t)
                        if t == 0 then return 0 end
                        if t == 1 then return 1 end
                        return -(2^(10*t-10)) * math.sin((t*10-10.75)*(2*pi)/3)
                      end,
        outElastic  = function(t)
                        if t == 0 then return 0 end
                        if t == 1 then return 1 end
                        return 2^(-10*t) * math.sin((t*10-0.75)*(2*pi)/3) + 1
                      end,
        outBounce   = function(t)
                        local n1, d1 = 7.5625, 2.75
                        if t < 1/d1 then return n1*t*t
                        elseif t < 2/d1 then t=t-1.5/d1;  return n1*t*t+0.75
                        elseif t < 2.5/d1 then t=t-2.25/d1; return n1*t*t+0.9375
                        else t=t-2.625/d1; return n1*t*t+0.984375
                        end
                      end,
    }
    bfmath.ease.inBounce = function(t) return 1 - bfmath.ease.outBounce(1-t) end
    bfmath.ease.inOutBounce = function(t)
        return t < 0.5
            and (1 - bfmath.ease.outBounce(1-2*t)) / 2
            or  (1 + bfmath.ease.outBounce(2*t-1)) / 2
    end

    --- Apply an easing function by name string (matches Heck easing names).
    --- Falls back to linear if unknown.
    --- @param name string  e.g. "easeInOutSine"
    --- @param t    number  0-1
    --- @return number
    function bfmath.applyEasing(name, t)
        -- Strip "ease" prefix and lowercase first char
        local key = name:match("^ease(.+)$") or name
        key = key:sub(1,1):lower() .. key:sub(2)
        local fn = bfmath.ease[key] or bfmath.ease.linear
        return fn(t)
    end

    -- ─── Beat / time conversion ──────────────────────────────────────────────────

    --- Convert a beat value to seconds given BPM.
    function bfmath.beatToSeconds(beat, bpm)
        return beat * 60 / bpm
    end

    --- Convert seconds to beats given BPM.
    function bfmath.secondsToBeat(secs, bpm)
        return secs * bpm / 60
    end

    -- ─── Keyframe helpers ────────────────────────────────────────────────────────

    --- Generate evenly-spaced keyframes by sampling a function f(t) over [0,1].
    --- @param f        fun(t:number): number[]   Returns a vec at time t
    --- @param steps    integer                  Number of keyframes (including endpoints)
    --- @param easing   string|nil               Heck easing name to append to each frame
    --- @return table[]
    function bfmath.sampleKeyframes(f, steps, easing)
        local frames = {}
        for i = 0, steps - 1 do
            local t   = i / (steps - 1)
            local val = f(t)
            local kf  = {}
            for _, v in ipairs(val) do table.insert(kf, v) end
            table.insert(kf, t)
            if easing then table.insert(kf, easing) end
            table.insert(frames, kf)
        end
        return frames
    end

    return bfmath
end)()

-- ── Module: note ────────────────────────────────────────────────────────
_BF_MODULES["note"] = (function()

    --- @class Note
    local Note = {}
    Note.__index = Note

    --- Internal: wrap a raw colorNote table.
    --- @param raw table
    --- @return Note
    function Note.wrap(raw)
        return setmetatable({ _raw = raw }, Note)
    end

    --- Create a brand-new color note.
    --- @param beat    number   Beat time
    --- @param x       integer  Column  (0-3)
    --- @param y       integer  Row     (0-2)
    --- @param color   integer  0=left/red, 1=right/blue
    --- @param direction integer  Cut direction (0=up … 8=dot)
    --- @return Note
    function Note.new(beat, x, y, color, direction)
        return Note.wrap({
            b = beat or 0,
            x = x    or 0,
            y = y    or 0,
            c = color or 0,
            d = direction or 0,
            customData = {},
        })
    end

    -- ─── Base fields ─────────────────────────────────────────────────────────────

    --- @return number
    function Note:getBeat()         return self._raw.b end
    --- @param v number
    function Note:setBeat(v)        self._raw.b = v; return self end

    --- @return integer
    function Note:getX()            return self._raw.x end
    --- @param v integer
    function Note:setX(v)           self._raw.x = v; return self end

    --- @return integer
    function Note:getY()            return self._raw.y end
    --- @param v integer
    function Note:setY(v)           self._raw.y = v; return self end

    --- @return integer  0=red, 1=blue
    function Note:getColor()        return self._raw.c end
    --- @param v integer
    function Note:setColor(v)       self._raw.c = v; return self end

    --- @return integer  Cut direction
    function Note:getDirection()    return self._raw.d end
    --- @param v integer
    function Note:setDirection(v)   self._raw.d = v; return self end

    -- ─── customData helpers ───────────────────────────────────────────────────────

    local function cd(note)
        note._raw.customData = note._raw.customData or {}
        return note._raw.customData
    end

    -- Noodle Extensions ────────────────────────────────────────────────────────────

    --- Assign this note to a named track (or array of tracks).
    --- @param track string|string[]
    function Note:setTrack(track)       cd(self).track = track; return self end
    function Note:getTrack()            return cd(self).track end

    --- Noodle: override note spawn position in world-space.
    --- @param vec number[]  {x,y,z}
    function Note:setNoteJumpStartBeatOffset(v) cd(self).noteJumpStartBeatOffset = v; return self end

    --- Noodle: disable the note's look-at-player rotation.
    --- @param v boolean
    function Note:setDisableNoteLook(v) cd(self).disableNoteLook = v; return self end

    --- Noodle: make note non-interactable (no score, no fail).
    --- @param v boolean
    function Note:setInteractable(v)    cd(self).interactable = v; return self end

    --- Noodle: set fake note flag (no score, still visible).
    --- @param v boolean
    function Note:setFake(v)            cd(self).fake = v; return self end

    --- Noodle: local rotation offset applied before spawn movement.
    --- @param vec number[]  {x,y,z}  Euler degrees
    function Note:setLocalRotation(v)   cd(self).localRotation = v; return self end

    --- Noodle: world rotation (applied after spawn).
    --- @param vec number[]  {x,y,z}  Euler degrees
    function Note:setWorldRotation(v)   cd(self).worldRotation = v; return self end

    --- Noodle: override note position {x, y} in lane/row units.
    --- @param vec number[]  {x,y}
    function Note:setCoordinates(v)     cd(self).coordinates = v; return self end

    -- Noodle per-note animation ────────────────────────────────────────────────────
    -- All animation values follow Heck keyframe format:
    --   single value : {x,y,z}             (constant)
    --   keyframed    : {{x,y,z,t}, ...}    (time 0-1 relative to note lifetime)
    --   eased        : {{x,y,z,t,"easeInOutSine"}, ...}

    local function anim(note)
        local c = cd(note)
        c.animation = c.animation or {}
        return c.animation
    end

    --- @param v any  Heck keyframe value
    function Note:setOffsetPosition(v)     anim(self).offsetPosition     = v; return self end
    function Note:setOffsetWorldRotation(v)anim(self).offsetWorldRotation= v; return self end
    function Note:setLocalPosition(v)      anim(self).localPosition      = v; return self end
    function Note:setLocalRotationAnim(v)  anim(self).localRotation      = v; return self end
    function Note:setScale(v)              anim(self).scale              = v; return self end
    function Note:setDissolve(v)           anim(self).dissolve           = v; return self end
    function Note:setDissolveArrow(v)      anim(self).dissolveArrow      = v; return self end
    function Note:setInteractableAnim(v)   anim(self).interactable       = v; return self end
    function Note:setDefinitePosition(v)   anim(self).definitePosition   = v; return self end
    function Note:setColor4(v)             anim(self).color              = v; return self end

    -- Chroma ───────────────────────────────────────────────────────────────────────

    --- Chroma: override note color. {r,g,b} or {r,g,b,a} (0-1 range).
    --- @param rgba number[]
    function Note:setChromaColor(rgba)  cd(self).color = rgba; return self end

    --- Chroma: disable default color scheme on this note.
    --- @param v boolean
    function Note:setDisableDebris(v)   cd(self).disableDebris = v; return self end

    --- Chroma: spawnEffect override.
    --- @param v boolean
    function Note:setSpawnEffect(v)     cd(self).spawnEffect = v; return self end

    -- ─── Fluent animation shorthand (proxy table, write-only) ────────────────────
    -- Allows:  note.animation.offsetPosition = {0,1,0}
    -- instead of: note:setOffsetPosition({0,1,0})

    Note.animation = {}  -- placeholder; resolved via __index below

    local animProxy_mt = {
        __newindex = function(proxy, key, value)
            local n = proxy._note
            anim(n)[key] = value
        end,
        __index = function(proxy, key)
            local n = proxy._note
            return anim(n)[key]
        end,
    }

    function Note:__index(key)
        if key == "animation" then
            return setmetatable({ _note = self }, animProxy_mt)
        end
        return Note[key]
    end

    return Note
end)()

-- ── Module: wall ────────────────────────────────────────────────────────
_BF_MODULES["wall"] = (function()

    --- @class Wall
    local Wall = {}
    Wall.__index = Wall

    function Wall.wrap(raw)
        return setmetatable({ _raw = raw }, Wall)
    end

    --- Create a new obstacle.
    --- @param beat     number
    --- @param x        integer  Column
    --- @param y        integer  Row (0=bottom)
    --- @param duration number   In beats
    --- @param width    integer
    --- @param height   integer
    function Wall.new(beat, x, y, duration, width, height)
        return Wall.wrap({
            b  = beat     or 0,
            x  = x        or 0,
            y  = y        or 0,
            d  = duration or 1,
            w  = width    or 1,
            h  = height   or 1,
            customData = {},
        })
    end

    -- Base fields
    function Wall:getBeat()     return self._raw.b end
    function Wall:setBeat(v)    self._raw.b = v; return self end
    function Wall:getX()        return self._raw.x end
    function Wall:setX(v)       self._raw.x = v; return self end
    function Wall:getY()        return self._raw.y end
    function Wall:setY(v)       self._raw.y = v; return self end
    function Wall:getDuration() return self._raw.d end
    function Wall:setDuration(v)self._raw.d = v; return self end
    function Wall:getWidth()    return self._raw.w end
    function Wall:setWidth(v)   self._raw.w = v; return self end
    function Wall:getHeight()   return self._raw.h end
    function Wall:setHeight(v)  self._raw.h = v; return self end

    local function cd(w)
        w._raw.customData = w._raw.customData or {}
        return w._raw.customData
    end

    local function anim(w)
        local c = cd(w)
        c.animation = c.animation or {}
        return c.animation
    end

    -- Noodle
    function Wall:setTrack(v)          cd(self).track       = v; return self end
    function Wall:setFake(v)           cd(self).fake        = v; return self end
    function Wall:setInteractable(v)   cd(self).interactable= v; return self end
    function Wall:setCoordinates(v)    cd(self).coordinates = v; return self end  -- {x,y}
    function Wall:setWorldRotation(v)  cd(self).worldRotation = v; return self end
    function Wall:setLocalRotation(v)  cd(self).localRotation = v; return self end
    function Wall:setSize(v)           cd(self).size        = v; return self end  -- {w,h,d}

    -- Noodle animation
    function Wall:setOffsetPosition(v)      anim(self).offsetPosition      = v; return self end
    function Wall:setOffsetWorldRotation(v) anim(self).offsetWorldRotation = v; return self end
    function Wall:setLocalRotationAnim(v)   anim(self).localRotation       = v; return self end
    function Wall:setScale(v)               anim(self).scale               = v; return self end
    function Wall:setDissolve(v)            anim(self).dissolve            = v; return self end
    function Wall:setDefinitePosition(v)    anim(self).definitePosition    = v; return self end
    function Wall:setColor4(v)              anim(self).color               = v; return self end

    -- Chroma
    function Wall:setChromaColor(rgba)  cd(self).color = rgba; return self end

    -- animation proxy (same pattern as note)
    local animProxy_mt = {
        __newindex = function(proxy, key, value) anim(proxy._wall)[key] = value end,
        __index    = function(proxy, key)        return anim(proxy._wall)[key]  end,
    }

    function Wall:__index(key)
        if key == "animation" then
            return setmetatable({ _wall = self }, animProxy_mt)
        end
        return Wall[key]
    end

    return Wall
end)()

-- ── Module: bomb ────────────────────────────────────────────────────────
_BF_MODULES["bomb"] = (function()

    local Bomb = {}
    Bomb.__index = Bomb

    function Bomb.wrap(raw)
        return setmetatable({ _raw = raw }, Bomb)
    end

    function Bomb.new(beat, x, y)
        return Bomb.wrap({ b = beat or 0, x = x or 0, y = y or 0, customData = {} })
    end

    function Bomb:getBeat()   return self._raw.b end
    function Bomb:setBeat(v)  self._raw.b = v; return self end
    function Bomb:getX()      return self._raw.x end
    function Bomb:setX(v)     self._raw.x = v; return self end
    function Bomb:getY()      return self._raw.y end
    function Bomb:setY(v)     self._raw.y = v; return self end

    local function cd(b)
        b._raw.customData = b._raw.customData or {}
        return b._raw.customData
    end

    local function anim(b)
        local c = cd(b)
        c.animation = c.animation or {}
        return c.animation
    end

    function Bomb:setTrack(v)         cd(self).track = v; return self end
    function Bomb:setFake(v)          cd(self).fake  = v; return self end
    function Bomb:setInteractable(v)  cd(self).interactable = v; return self end
    function Bomb:setCoordinates(v)   cd(self).coordinates  = v; return self end
    function Bomb:setChromaColor(v)   cd(self).color = v; return self end
    function Bomb:setOffsetPosition(v)     anim(self).offsetPosition = v; return self end
    function Bomb:setDissolve(v)           anim(self).dissolve       = v; return self end
    function Bomb:setDefinitePosition(v)   anim(self).definitePosition = v; return self end

    local animProxy_mt = {
        __newindex = function(proxy, key, value) anim(proxy._bomb)[key] = value end,
        __index    = function(proxy, key)        return anim(proxy._bomb)[key]  end,
    }

    function Bomb:__index(key)
        if key == "animation" then
            return setmetatable({ _bomb = self }, animProxy_mt)
        end
        return Bomb[key]
    end

    return Bomb
end)()

-- ── Module: event ───────────────────────────────────────────────────────
_BF_MODULES["event"] = (function()

    local Event = {}
    Event.__index = Event

    function Event.wrap(raw)
        return setmetatable({ _raw = raw }, Event)
    end

    --- @param beat   number
    --- @param type   integer  Light event type ID
    --- @param value  integer  Light state value
    --- @param float  number   Float value (brightness)
    function Event.new(beat, etype, value, float)
        return Event.wrap({ b = beat or 0, et = etype or 0, i = value or 0, f = float or 1, customData = {} })
    end

    function Event:getBeat()    return self._raw.b  end
    function Event:setBeat(v)   self._raw.b = v; return self end
    function Event:getType()    return self._raw.et end
    function Event:setType(v)   self._raw.et = v; return self end
    function Event:getValue()   return self._raw.i  end
    function Event:setValue(v)  self._raw.i = v; return self end
    function Event:getFloat()   return self._raw.f  end
    function Event:setFloat(v)  self._raw.f = v; return self end

    local function cd(e)
        e._raw.customData = e._raw.customData or {}
        return e._raw.customData
    end

    --- Chroma: override light color  {r,g,b} or {r,g,b,a}
    function Event:setChromaColor(rgba)     cd(self).color     = rgba; return self end
    --- Chroma: light gradient  { startColor={r,g,b,a}, endColor={r,g,b,a}, duration=n, easing="easeLinear" }
    function Event:setLightGradient(grad)   cd(self).lightGradient = grad; return self end
    --- Chroma: target specific light IDs  {1,2,3,...}
    function Event:setLightID(ids)          cd(self).lightID   = ids; return self end
    --- Chroma: propID for grouped prop animations
    function Event:setPropID(v)             cd(self).propID    = v; return self end
    --- Chroma: lerpType  "HSV" or "RGB"
    function Event:setLerpType(v)           cd(self).lerpType  = v; return self end
    --- Chroma: easing for gradient events
    function Event:setEasing(v)             cd(self).easing    = v; return self end

    return Event
end)()

-- ── Module: heck ────────────────────────────────────────────────────────
_BF_MODULES["heck"] = (function()

    local heck = {}

    -- ─── AnimateTrack ─────────────────────────────────────────────────────────────

    --- Build an AnimateTrack custom event.
    --- @param track    string|string[]  Target track(s)
    --- @param beat     number           Beat time
    --- @param anim     table            Keyframe properties  { offsetPosition=..., ... }
    --- @param duration number|nil       Duration in beats (default 0)
    --- @param easing   string|nil       Global easing override
    --- @return table  Raw custom event table
    function heck.animateTrack(track, beat, anim, duration, easing)
        local d = {
            b = beat,
            t = "AnimateTrack",
            d = {
                track    = track,
                duration = duration or 0,
            },
        }
        if easing then d.d.easing = easing end
        -- Merge animation properties straight into d.d
        for k, v in pairs(anim) do
            d.d[k] = v
        end
        return d
    end

    -- ─── AssignPathAnimation ──────────────────────────────────────────────────────

    --- Build an AssignPathAnimation custom event.
    --- Path animation plays relative to each object's own spawn lifetime (0→1).
    --- @param track  string|string[]
    --- @param beat   number
    --- @param anim   table   Keyframe properties
    --- @param easing string|nil
    --- @return table
    function heck.assignPathAnimation(track, beat, anim, easing)
        local d = {
            b = beat,
            t = "AssignPathAnimation",
            d = { track = track },
        }
        if easing then d.d.easing = easing end
        for k, v in pairs(anim) do
            d.d[k] = v
        end
        return d
    end

    -- ─── AssignTrackParent ────────────────────────────────────────────────────────

    --- Build an AssignTrackParent event — parents childTrack under parentTrack.
    --- @param childTrack   string
    --- @param parentTrack  string
    --- @param beat         number
    --- @param worldPositionStays boolean|nil  (default false)
    --- @return table
    function heck.assignTrackParent(childTrack, parentTrack, beat, worldPositionStays)
        return {
            b = beat,
            t = "AssignTrackParent",
            d = {
                childrenTracks     = type(childTrack) == "table" and childTrack or { childTrack },
                parentTrack        = parentTrack,
                worldPositionStays = worldPositionStays or false,
            },
        }
    end

    -- ─── AssignPlayerToTrack ─────────────────────────────────────────────────────

    --- Attach the player rig to a track so it can be animated.
    --- @param track  string
    --- @param beat   number
    --- @param target string|nil  "Root","Head","LeftHand","RightHand" (default "Root")
    --- @return table
    function heck.assignPlayerToTrack(track, beat, target)
        return {
            b = beat,
            t = "AssignPlayerToTrack",
            d = {
                track  = track,
                target = target or "Root",
            },
        }
    end

    -- ─── Keyframe builders ────────────────────────────────────────────────────────

    --- Build a single keyframe.  t is 0-1 for path anim, beat for track anim.
    --- @param  ...  Values followed by time, then optional easing string
    --- e.g.  heck.kf(0, 1, 0, 0.5, "easeInOutSine")
    function heck.kf(...)
        return { ... }
    end

    --- Constant (single-value) shorthand: no time component needed in path anim.
    --- @param ... number  Vec values  e.g.  heck.const(0,1,0)
    function heck.const(...)
        return { ... }
    end

    --- Build a full keyframe list from a flat list of {values..., t [, easing]} tables.
    --- @param frames table[]
    --- @return table[]
    function heck.keyframes(frames)
        return frames
    end

    -- ─── Common easing constants ─────────────────────────────────────────────────
    heck.easing = {
        linear        = "easeLinear",
        inSine        = "easeInSine",
        outSine       = "easeOutSine",
        inOutSine     = "easeInOutSine",
        inQuad        = "easeInQuad",
        outQuad       = "easeOutQuad",
        inOutQuad     = "easeInOutQuad",
        inCubic       = "easeInCubic",
        outCubic      = "easeOutCubic",
        inOutCubic    = "easeInOutCubic",
        inExpo        = "easeInExpo",
        outExpo       = "easeOutExpo",
        inOutExpo     = "easeInOutExpo",
        inElastic     = "easeInElastic",
        outElastic    = "easeOutElastic",
        inOutElastic  = "easeInOutElastic",
        inBounce      = "easeInBounce",
        outBounce     = "easeOutBounce",
        inOutBounce   = "easeInOutBounce",
        step          = "easeStep",
    }

    return heck
end)()

-- ── Module: chroma ──────────────────────────────────────────────────────
_BF_MODULES["chroma"] = (function()

    local chroma = {}

    -- ─── Color utilities ─────────────────────────────────────────────────────────

    --- Build an RGB color table (0-1 range per channel).
    --- @param r number
    --- @param g number
    --- @param b number
    --- @param a number|nil  Alpha, default 1
    --- @return number[]
    function chroma.rgb(r, g, b, a)
        return { r, g, b, a or 1 }
    end

    --- Convert 0-255 integer channels to 0-1 table.
    --- @return number[]
    function chroma.rgb255(r, g, b, a)
        return { r / 255, g / 255, b / 255, (a or 255) / 255 }
    end

    --- Convert a hex color string "#RRGGBB" or "#RRGGBBAA" to a {r,g,b,a} table.
    --- @param hex string
    --- @return number[]
    function chroma.hex(hex)
        hex = hex:gsub("#", "")
        local r = tonumber(hex:sub(1,2), 16) / 255
        local g = tonumber(hex:sub(3,4), 16) / 255
        local b = tonumber(hex:sub(5,6), 16) / 255
        local a = hex:len() >= 8 and tonumber(hex:sub(7,8), 16) / 255 or 1
        return { r, g, b, a }
    end

    --- Convert HSV (0-1 range) to an RGB {r,g,b,1} table.
    --- @param h number  Hue 0-1
    --- @param s number  Saturation 0-1
    --- @param v number  Value/brightness 0-1
    --- @return number[]
    function chroma.hsv(h, s, v)
        if s == 0 then return { v, v, v, 1 } end
        local i = math.floor(h * 6)
        local f = h * 6 - i
        local p = v * (1 - s)
        local q = v * (1 - f * s)
        local t = v * (1 - (1 - f) * s)
        local r, g, b
        i = i % 6
        if i == 0 then r,g,b = v,t,p
        elseif i == 1 then r,g,b = q,v,p
        elseif i == 2 then r,g,b = p,v,t
        elseif i == 3 then r,g,b = p,q,v
        elseif i == 4 then r,g,b = t,p,v
        else               r,g,b = v,p,q
        end
        return { r, g, b, 1 }
    end

    --- Linearly interpolate between two {r,g,b,a} colors.
    --- @param a number[]
    --- @param b number[]
    --- @param t number   0-1
    --- @return number[]
    function chroma.lerpColor(a, b, t)
        return {
            a[1] + (b[1] - a[1]) * t,
            a[2] + (b[2] - a[2]) * t,
            a[3] + (b[3] - a[3]) * t,
            (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t,
        }
    end

    -- ─── Colour scheme (sabers / notes / environment) ────────────────────────────

    --- Build a Chroma _colorScheme block for map customData.
    --- Pass nil for any color you want to leave at default.
    --- @param colorLeft  number[]|nil  Left saber / red note color
    --- @param colorRight number[]|nil  Right saber / blue note color
    --- @param envLeft    number[]|nil  Environment left color
    --- @param envRight   number[]|nil  Environment right color
    --- @param obstacleColor number[]|nil
    --- @return table
    function chroma.colorScheme(colorLeft, colorRight, envLeft, envRight, obstacleColor)
        local s = {}
        if colorLeft     then s.colorLeft     = colorLeft     end
        if colorRight    then s.colorRight    = colorRight    end
        if envLeft       then s.envColorLeft  = envLeft       end
        if envRight      then s.envColorRight = envRight      end
        if obstacleColor then s.obstacleColor = obstacleColor end
        return s
    end

    -- ─── Environment enhancements ────────────────────────────────────────────────
    -- These go into map customData.environment[]

    --- Target an environment component by regex ID or geometry.
    --- @param id       string        GameObject name/regex
    --- @param lookupMethod string    "Regex","Exact","Contains","StartsWith","EndsWith" (default "Regex")
    --- @return table  Partial env object, add fields then pass to map:addEnvironment()
    function chroma.envTarget(id, lookupMethod)
        return { id = id, lookupMethod = lookupMethod or "Regex" }
    end

    --- Convenience: duplicate an env object and position it.
    --- @param id       string
    --- @param position number[]  {x,y,z}
    --- @param rotation number[]|nil  {x,y,z} Euler
    --- @param scale    number[]|nil  {x,y,z}
    --- @param track    string|nil
    --- @return table
    function chroma.envPlace(id, position, rotation, scale, track)
        local e = {
            id           = id,
            lookupMethod = "Regex",
            position     = position,
        }
        if rotation then e.rotation = rotation end
        if scale    then e.scale    = scale    end
        if track    then e.track    = track    end
        return e
    end

    --- Build a geometry (primitive) environment object.
    --- @param shape     string  "Sphere","Capsule","Cylinder","Cube","Plane","Quad","Triangle"
    --- @param material  table   { shader=..., color=..., track=... }
    --- @param position  number[]
    --- @param rotation  number[]|nil
    --- @param scale     number[]|nil
    --- @param track     string|nil
    --- @return table
    function chroma.envGeometry(shape, material, position, rotation, scale, track)
        local e = {
            geometry = {
                type     = shape,
                material = material,
            },
            position = position,
        }
        if rotation then e.rotation = rotation end
        if scale    then e.scale    = scale    end
        if track    then e.track    = track    end
        return e
    end

    --- Build a Chroma material table.
    --- @param shader string  "Standard","OpaqueLight","TransparentLight","BaseWater","BillieWater","BTSPillar","InterscopeConcrete","InterscopeCar","Obstacle","WaterfallMirror"
    --- @param color  number[]|nil
    --- @param shaderKeywords string[]|nil
    --- @return table
    function chroma.material(shader, color, shaderKeywords)
        local m = { shader = shader }
        if color          then m.color          = color          end
        if shaderKeywords then m.shaderKeywords = shaderKeywords end
        return m
    end

    -- ─── Light gradient helper ───────────────────────────────────────────────────

    --- Build a Chroma lightGradient block for use in event:setLightGradient().
    --- @param startColor number[]
    --- @param endColor   number[]
    --- @param duration   number   Beats
    --- @param easing     string|nil  (default "easeLinear")
    --- @return table
    function chroma.lightGradient(startColor, endColor, duration, easing)
        return {
            startColor = startColor,
            endColor   = endColor,
            duration   = duration,
            easing     = easing or "easeLinear",
        }
    end

    -- ─── Fog (Chroma/Heck) ───────────────────────────────────────────────────────

    --- Build a fog customEvent (AnimateTrack targeting the "FogTrack" reserved track).
    --- @param beat     number
    --- @param duration number   Beats
    --- @param attenuation  number|table  Keyframed or constant
    --- @param offset       number|table
    --- @param startY       number|table
    --- @param height       number|table
    --- @return table  Raw custom event
    function chroma.fogEvent(beat, duration, attenuation, offset, startY, height)
        return {
            b = beat,
            t = "AnimateTrack",
            d = {
                track       = "FogTrack",  -- reserved Chroma fog track
                duration    = duration,
                attenuation = attenuation,
                offset      = offset,
                startY      = startY,
                height      = height,
            },
        }
    end

    return chroma
end)()

-- ── Module: noodle ──────────────────────────────────────────────────────
_BF_MODULES["noodle"] = (function()

    local noodle = {}

    -- ─── Point definitions ────────────────────────────────────────────────────────
    -- Stored in map.customData.pointDefinitions as { name=..., points={{...},...} }
    -- Objects can reference them by name instead of embedding keyframes inline.

    --- Build a pointDefinition entry.
    --- @param name   string
    --- @param points table[]  Keyframe list
    --- @return table
    function noodle.pointDef(name, points)
        return { name = name, points = points }
    end

    --- Register a point definition on the map.
    --- @param map    Map
    --- @param name   string
    --- @param points table[]
    function noodle.registerPointDef(map, name, points)
        map._data.customData = map._data.customData or {}
        map._data.customData.pointDefinitions = map._data.customData.pointDefinitions or {}
        table.insert(map._data.customData.pointDefinitions, noodle.pointDef(name, points))
    end

    -- ─── Player movement ─────────────────────────────────────────────────────────
    -- Heck v3 uses AssignPlayerToTrack + AnimateTrack on that track.

    --- Convenience: build the two custom events needed to animate the player.
    --- Inserts AssignPlayerToTrack at beat 0 and returns AnimateTrack event.
    ---
    --- @param map       Map
    --- @param track     string
    --- @param beat      number   When AnimateTrack fires
    --- @param duration  number
    --- @param anim      table    { offsetPosition=..., offsetWorldRotation=..., ... }
    --- @param easing    string|nil
    function noodle.movePlayer(map, track, beat, duration, anim, easing)
        local heck = _bf_require("heck")
        -- Assign at beat 0 so the track exists before the animation fires
        map:addCustomEvent(heck.assignPlayerToTrack(track, 0))
        local ev = heck.animateTrack(track, beat, anim, duration, easing)
        map:addCustomEvent(ev)
    end

    -- ─── Settings / modifiers ────────────────────────────────────────────────────

    --- Common Heck _settings presets.
    noodle.settings = {
        --- Recommend No-Fail modifier
        noFail = function() return { modifiers = { noFailOn0Energy = true } } end,
        --- Recommend static lights (better performance for VR)
        staticLights = function() return { environments = { overrideEnvironments = false } } end,
        --- Require Noodle Extensions
        requireNoodle = function()
            return { requirements = { "Noodle Extensions" } }
        end,
        --- Require Chroma
        requireChroma = function()
            return { requirements = { "Chroma" } }
        end,
        --- Require both
        requireAll = function()
            return { requirements = { "Noodle Extensions", "Chroma" } }
        end,
        --- Suggest (optional) both mods
        suggestAll = function()
            return { suggestions = { "Noodle Extensions", "Chroma" } }
        end,
    }

    -- ─── Coordinate helpers ───────────────────────────────────────────────────────

    --- Convert logical lane/row to Noodle coordinates.
    --- Noodle coordinates use centre-of-playfield origin:
    ---   x: lane 0→-1.5, 1→-0.5, 2→0.5, 3→1.5
    ---   y: row  0→0,    1→1,     2→2
    --- @param lane integer 0-3
    --- @param row  integer 0-2
    --- @return number, number  (x, y)
    function noodle.toCoords(lane, row)
        return lane - 1.5, row
    end

    --- Build a coordinates pair table {x, y} from lane/row.
    function noodle.coords(lane, row)
        local x, y = noodle.toCoords(lane, row)
        return { x, y }
    end

    -- ─── Bulk track assignment ────────────────────────────────────────────────────

    --- Assign all notes in a beat range to a track.
    --- @param map    Map
    --- @param track  string
    --- @param from   number  Start beat (inclusive)
    --- @param to     number  End beat (inclusive)
    function noodle.assignNoteTrack(map, track, from, to)
        map:notes(function(n)
            local b = n:getBeat()
            if b >= from and b <= to then
                n:setTrack(track)
            end
        end)
    end

    --- Assign all walls in a beat range to a track.
    function noodle.assignWallTrack(map, track, from, to)
        map:walls(function(w)
            local b = w:getBeat()
            if b >= from and b <= to then
                w:setTrack(track)
            end
        end)
    end

    return noodle
end)()

-- ── Module: map ─────────────────────────────────────────────────────────
_BF_MODULES["map"] = (function()

    local json = _bf_require("json")
    local Note  = _bf_require("note")
    local Wall  = _bf_require("wall")
    local Bomb  = _bf_require("bomb")
    local Event = _bf_require("event")

    --- @class Map
    local Map = {}
    Map.__index = Map

    --- Load a beatmap .dat file and return a Map object.
    --- @param path string  Path to the difficulty .dat file (e.g. "ExpertPlus.dat")
    --- @return Map
    function Map.load(path)
        local f = assert(io.open(path, "r"), "BeatForge: could not open '" .. path .. "'")
        local raw = f:read("*a")
        f:close()

        local data = json.decode(raw)

        local self = setmetatable({
            _path    = path,
            _data    = data,
            _notes   = {},
            _walls   = {},
            _bombs   = {},
            _arcs    = {},
            _chains  = {},
            _events  = {},
        }, Map)

        -- Wrap every raw object in its typed wrapper
        for _, n in ipairs(data.colorNotes       or {}) do table.insert(self._notes,  Note.wrap(n))  end
        for _, w in ipairs(data.obstacles        or {}) do table.insert(self._walls,  Wall.wrap(w))  end
        for _, b in ipairs(data.bombNotes        or {}) do table.insert(self._bombs,  Bomb.wrap(b))  end
        for _, e in ipairs(data.basicBeatmapEvents or {}) do table.insert(self._events, Event.wrap(e)) end
        -- arcs / chains pass through as raw tables for now
        for _, a in ipairs(data.sliders          or {}) do table.insert(self._arcs,   a) end
        for _, c in ipairs(data.burstSliders     or {}) do table.insert(self._chains, c) end

        return self
    end

    --- Create a brand-new empty map (useful for generative scripts).
    --- @return Map
    function Map.new()
        return setmetatable({
            _path    = "output.dat",
            _data    = { version = "3.3.0", colorNotes = {}, obstacles = {}, bombNotes = {},
                         basicBeatmapEvents = {}, sliders = {}, burstSliders = {},
                         customData = {} },
            _notes   = {}, _walls  = {}, _bombs  = {},
            _arcs    = {}, _chains = {}, _events = {},
        }, Map)
    end

    -- ─── Collection iterators ─────────────────────────────────────────────────────

    --- Iterate all color notes, passing each to callback.
    --- The callback may modify the note in-place.
    --- @param fn fun(note: Note)
    function Map:notes(fn)
        for _, n in ipairs(self._notes) do fn(n) end
        return self
    end

    --- Iterate all obstacles (walls).
    --- @param fn fun(wall: Wall)
    function Map:walls(fn)
        for _, w in ipairs(self._walls) do fn(w) end
        return self
    end

    --- Iterate all bomb notes.
    --- @param fn fun(bomb: Bomb)
    function Map:bombs(fn)
        for _, b in ipairs(self._bombs) do fn(b) end
        return self
    end

    --- Iterate basic beat events.
    --- @param fn fun(event: Event)
    function Map:events(fn)
        for _, e in ipairs(self._events) do fn(e) end
        return self
    end

    --- Filter notes, returning a new table of matches.
    --- @param predicate fun(note: Note): boolean
    --- @return Note[]
    function Map:filterNotes(predicate)
        local out = {}
        for _, n in ipairs(self._notes) do
            if predicate(n) then table.insert(out, n) end
        end
        return out
    end

    --- Add a new note to the map.
    --- @param note Note
    function Map:addNote(note)
        table.insert(self._notes, note)
        return self
    end

    --- Add a new wall to the map.
    --- @param wall Wall
    function Map:addWall(wall)
        table.insert(self._walls, wall)
        return self
    end

    --- Add a custom event (Heck AnimateTrack / AssignPathAnimation etc.)
    --- @param event table  Raw custom event table
    function Map:addCustomEvent(event)
        self._data.customData = self._data.customData or {}
        self._data.customData.customEvents = self._data.customData.customEvents or {}
        table.insert(self._data.customData.customEvents, event)
        return self
    end

    --- Add an environment enhancement object.
    --- @param env table  Raw environment table
    function Map:addEnvironment(env)
        self._data.customData = self._data.customData or {}
        self._data.customData.environment = self._data.customData.environment or {}
        table.insert(self._data.customData.environment, env)
        return self
    end

    --- Set the _settings block (Heck modifiers / recommended settings).
    --- @param settings table
    function Map:setSettings(settings)
        self._data.customData = self._data.customData or {}
        self._data.customData._settings = settings
        return self
    end

    -- ─── Save ────────────────────────────────────────────────────────────────────

    --- Serialise back to JSON and write to disk.
    --- @param path string|nil  Override output path (defaults to loaded path)
    function Map:save(path)
        path = path or self._path

        -- Flush wrappers back into the raw data arrays
        self._data.colorNotes         = {}
        self._data.obstacles          = {}
        self._data.bombNotes          = {}
        self._data.basicBeatmapEvents = {}
        self._data.sliders            = self._arcs
        self._data.burstSliders       = self._chains

        for _, n in ipairs(self._notes)  do table.insert(self._data.colorNotes,  n._raw) end
        for _, w in ipairs(self._walls)  do table.insert(self._data.obstacles,   w._raw) end
        for _, b in ipairs(self._bombs)  do table.insert(self._data.bombNotes,   b._raw) end
        for _, e in ipairs(self._events) do table.insert(self._data.basicBeatmapEvents, e._raw) end

        local out = json.encode(self._data)
        local f   = assert(io.open(path, "w"), "BeatForge: could not write '" .. path .. "'")
        f:write(out)
        f:close()

        print(string.format("[BeatForge] Saved → %s  (%d notes, %d walls, %d bombs)",
            path, #self._notes, #self._walls, #self._bombs))
        return self
    end

    return Map
end)()

-- ── Long-name aliases ────────────────────────────────────────────────────────
_BF_MODULES["beatforge.utils.json"] = _BF_MODULES["json"]
_BF_MODULES["beatforge.utils.bfmath"] = _BF_MODULES["bfmath"]
_BF_MODULES["beatforge.core.note"] = _BF_MODULES["note"]
_BF_MODULES["beatforge.core.wall"] = _BF_MODULES["wall"]
_BF_MODULES["beatforge.core.bomb"] = _BF_MODULES["bomb"]
_BF_MODULES["beatforge.core.event"] = _BF_MODULES["event"]
_BF_MODULES["beatforge.core.map"] = _BF_MODULES["map"]
_BF_MODULES["beatforge.modules.heck"] = _BF_MODULES["heck"]
_BF_MODULES["beatforge.modules.chroma"] = _BF_MODULES["chroma"]
_BF_MODULES["beatforge.modules.noodle"] = _BF_MODULES["noodle"]

-- ── Public API ───────────────────────────────────────────────────────────────
local BeatForge = {}
BeatForge.Map    = _BF_MODULES["map"]
BeatForge.Note   = _BF_MODULES["note"]
BeatForge.Wall   = _BF_MODULES["wall"]
BeatForge.Bomb   = _BF_MODULES["bomb"]
BeatForge.Event  = _BF_MODULES["event"]
BeatForge.heck   = _BF_MODULES["heck"]
BeatForge.chroma = _BF_MODULES["chroma"]
BeatForge.noodle = _BF_MODULES["noodle"]
BeatForge.math   = _BF_MODULES["bfmath"]

function BeatForge.load(path)  return BeatForge.Map.load(path) end
function BeatForge.new()       return BeatForge.Map.new()      end

BeatForge.VERSION = "1.0.0"
return BeatForge