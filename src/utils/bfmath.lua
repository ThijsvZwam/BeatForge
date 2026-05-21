--- BeatForge: utils/math.lua
--- Numeric helpers used across the library.

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
