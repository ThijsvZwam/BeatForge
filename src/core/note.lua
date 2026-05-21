--- BeatForge: core/note.lua
--- Wraps a v3 colorNote raw table and exposes typed getters/setters
--- for base fields, Noodle Extensions, and Chroma custom data.

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
