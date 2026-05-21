--- BeatForge: modules/noodle.lua
--- Noodle Extensions helpers that don't belong on a single object:
---   • Point definitions  (reusable keyframe lists stored in customData)
---   • Player movement events
---   • Global modifiers (_settings)

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
    local heck = require("beatforge.modules.heck")
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
