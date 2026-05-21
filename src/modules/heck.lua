--- BeatForge: modules/heck.lua
--- Builders for all Heck custom event types:
---   AnimateTrack, AssignPathAnimation,
---   AssignTrackParent, AssignPlayerToTrack
---
--- Usage:
---   local heck = require("beatforge.modules.heck")
---   map:addCustomEvent(heck.animateTrack("MyTrack", 8, { offsetPosition = {{0,0,0,0},{0,5,0,1}} }, 4))

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
