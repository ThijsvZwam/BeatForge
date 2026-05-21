--- BeatForge: core/map.lua
--- Main map object. Loads a beatmap .dat file, exposes
--- note/wall/bomb/arc/chain/event collections, and writes
--- the final file back to disk.

local json = require("beatforge.utils.json")
local Note  = require("beatforge.core.note")
local Wall  = require("beatforge.core.wall")
local Bomb  = require("beatforge.core.bomb")
local Event = require("beatforge.core.event")

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
