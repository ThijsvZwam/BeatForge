--- BeatForge: core/info.lua
--- Loads, manipulates, and saves info.dat (v2 format).
--- Handles per-difficulty requirements/suggestions/settings propagation
--- and Vivify bundle checksum injection.

local json = require("beatforge.utils.json")

--- @class InfoDat
local InfoDat = {}
InfoDat.__index = InfoDat

-- ─── Load / New ───────────────────────────────────────────────────────────────

--- Load an existing info.dat from disk.
--- @param path string  Defaults to "info.dat"
--- @return InfoDat
function InfoDat.load(path)
    path = path or "info.dat"
    local f = io.open(path, "r")
    if not f then
        error("BeatForge InfoDat: could not open '" .. path .. "'")
    end
    local raw = f:read("*a")
    f:close()
    return setmetatable({ _path = path, _data = json.decode(raw) }, InfoDat)
end

--- Create a minimal, empty info.dat object (for generative projects).
--- @return InfoDat
function InfoDat.new()
    return setmetatable({
        _path = "info.dat",
        _data = {
            _version             = "2.1.0",
            _songName            = "Unknown",
            _songSubName         = "",
            _songAuthorName      = "Unknown Artist",
            _levelAuthorName     = "",
            _beatsPerMinute      = 120,
            _shuffle             = 0,
            _shufflePeriod       = 0.5,
            _previewStartTime    = 12,
            _previewDuration     = 10,
            _songFilename        = "song.ogg",
            _coverImageFilename  = "cover.jpg",
            _environmentName     = "DefaultEnvironment",
            _allDirectionsEnvironmentName = "GlassDesertEnvironment",
            _customData          = {},
            _difficultyBeatmapSets = {},
        },
    }, InfoDat)
end

-- ─── Top-level metadata ───────────────────────────────────────────────────────

function InfoDat:getSongName()       return self._data._songName end
function InfoDat:setSongName(v)      self._data._songName = v; return self end
function InfoDat:getSongAuthor()     return self._data._songAuthorName end
function InfoDat:setSongAuthor(v)    self._data._songAuthorName = v; return self end
function InfoDat:getLevelAuthor()    return self._data._levelAuthorName end
function InfoDat:setLevelAuthor(v)   self._data._levelAuthorName = v; return self end
function InfoDat:getBPM()            return self._data._beatsPerMinute end
function InfoDat:setBPM(v)           self._data._beatsPerMinute = v; return self end
function InfoDat:getSongFilename()   return self._data._songFilename end
function InfoDat:setSongFilename(v)  self._data._songFilename = v; return self end
function InfoDat:getCoverFilename()  return self._data._coverImageFilename end
function InfoDat:setCoverFilename(v) self._data._coverImageFilename = v; return self end

-- ─── Diff lookup ─────────────────────────────────────────────────────────────

--- Iterate all difficulty entries in all beatmap sets.
--- Callback receives (diffEntry, setEntry).
--- @param fn fun(diff: table, set: table)
function InfoDat:eachDiff(fn)
    for _, set in ipairs(self._data._difficultyBeatmapSets or {}) do
        for _, diff in ipairs(set._difficultyBeatmaps or {}) do
            fn(diff, set)
        end
    end
end

--- Find a specific diff entry by characteristic + difficulty label.
--- @param characteristic string  e.g. "Standard", "OneSaber"
--- @param difficulty     string  e.g. "ExpertPlus"
--- @return table|nil
function InfoDat:findDiff(characteristic, difficulty)
    for _, set in ipairs(self._data._difficultyBeatmapSets or {}) do
        if set._beatmapCharacteristicName == characteristic then
            for _, diff in ipairs(set._difficultyBeatmaps or {}) do
                if diff._difficulty == difficulty then
                    return diff
                end
            end
        end
    end
    return nil
end

--- Find a diff entry by its filename.
--- @param filename string  e.g. "ExpertPlus.dat" or "ExpertPlusStandard.dat"
--- @return table|nil
function InfoDat:findDiffByFile(filename)
    local found
    self:eachDiff(function(diff)
        if diff._beatmapFilename == filename then found = diff end
    end)
    return found
end

-- ─── Per-diff custom data helpers ────────────────────────────────────────────

local function diffCD(diff)
    diff._customData = diff._customData or {}
    return diff._customData
end

--- Set requirements on a specific diff (by filename).
--- Merges with any existing requirements.
--- @param filename     string
--- @param requirements string[]
function InfoDat:setRequirements(filename, requirements)
    local diff = self:findDiffByFile(filename)
    if not diff then
        print("[BeatForge] InfoDat: diff not found for file '" .. filename .. "' – skipping requirements")
        return self
    end
    local cd = diffCD(diff)
    -- Merge: avoid duplicates
    local existing = {}
    for _, r in ipairs(cd._requirements or {}) do existing[r] = true end
    for _, r in ipairs(requirements) do existing[r] = true end
    local merged = {}
    for r in pairs(existing) do table.insert(merged, r) end
    table.sort(merged)
    cd._requirements = merged
    return self
end

--- Set suggestions on a specific diff (by filename).
--- @param filename    string
--- @param suggestions string[]
function InfoDat:setSuggestions(filename, suggestions)
    local diff = self:findDiffByFile(filename)
    if not diff then
        print("[BeatForge] InfoDat: diff not found for file '" .. filename .. "' – skipping suggestions")
        return self
    end
    local cd = diffCD(diff)
    local existing = {}
    for _, s in ipairs(cd._suggestions or {}) do existing[s] = true end
    for _, s in ipairs(suggestions) do existing[s] = true end
    local merged = {}
    for s in pairs(existing) do table.insert(merged, s) end
    table.sort(merged)
    cd._suggestions = merged
    return self
end

--- Set Heck _settings on a specific diff (by filename).
--- @param filename string
--- @param settings table
function InfoDat:setDiffSettings(filename, settings)
    local diff = self:findDiffByFile(filename)
    if not diff then
        print("[BeatForge] InfoDat: diff not found for file '" .. filename .. "' – skipping settings")
        return self
    end
    diffCD(diff)._settings = settings
    return self
end

--- Propagate exportSettings from a Map instance into this InfoDat.
--- Called automatically by Pipeline.export, but can also be called manually.
--- @param map      Map     The map object
--- @param filename string  The diff filename (e.g. "ExpertPlus.dat")
function InfoDat:applyMapSettings(map, filename)
    if not map._exportSettings then return self end
    local s = map._exportSettings
    if s.requirements then self:setRequirements(filename, s.requirements) end
    if s.suggestions  then self:setSuggestions(filename,  s.suggestions)  end
    if s.settings     then self:setDiffSettings(filename, s.settings)     end
    return self
end

-- ─── Vivify bundle CRC injection ─────────────────────────────────────────────
-- Vivify writes CRCs into bundleinfo.json after building the bundle.
-- The format is: { "bundleCRCs": { "_windows2019": 123, "_windows2021": 456, ... } }
-- These need to be copied into info.dat at _customData._assetBundle.

--- Read bundleinfo.json and copy all CRC values into info.dat _customData._assetBundle.
--- Any keys already present in _assetBundle are overwritten with the fresh values.
--- @param path string|nil  Path to bundleinfo.json, defaults to "bundleinfo.json"
--- @return InfoDat
function InfoDat:applyBundleInfo(path)
    path = path or "bundleinfo.json"
    local f = io.open(path, "r")
    if not f then
        error("[BeatForge] InfoDat: could not open '" .. path .. "'")
    end
    local raw = f:read("*a")
    f:close()

    local bi = json.decode(raw)
    if not bi.bundleCRCs then
        print("[BeatForge] InfoDat: bundleinfo.json has no 'bundleCRCs' key — skipping")
        return self
    end

    self._data._customData = self._data._customData or {}
    self._data._customData._assetBundle = self._data._customData._assetBundle or {}
    local ab = self._data._customData._assetBundle

    for key, crc in pairs(bi.bundleCRCs) do
        ab[key] = crc
        print(string.format("[BeatForge] Bundle CRC: %s = %d", key, crc))
    end

    return self
end

--- Remove a Vivify bundle CRC entry by key (e.g. "_windows2019").
--- @param key string
function InfoDat:removeVivifyBundle(key)
    local ab = (self._data._customData or {})._assetBundle
    if not ab then return self end
    ab[key] = nil
    return self
end

--- Get the stored CRC for a bundle by key (e.g. "_windows2021"). Returns nil if not found.
--- @param key string
--- @return integer|nil
function InfoDat:getBundleChecksum(key)
    return ((self._data._customData or {})._assetBundle or {})[key]
end

-- ─── Global info.dat customData ──────────────────────────────────────────────

--- Set the global contributors list (Chroma/BeatSaver standard).
--- @param contributors table[]  { { _role="Mapper", _name="...", _iconPath="..." }, ... }
function InfoDat:setContributors(contributors)
    self._data._customData = self._data._customData or {}
    self._data._customData._contributors = contributors
    return self
end

--- Set a global color scheme in info.dat customData._colorScheme.
--- @param scheme table  From chroma.colorScheme(...)
function InfoDat:setColorScheme(scheme)
    self._data._customData = self._data._customData or {}
    self._data._customData._colorScheme = scheme
    return self
end

--- Set the environment name.
--- @param name string  e.g. "BTSEnvironment"
function InfoDat:setEnvironment(name)
    self._data._environmentName = name
    return self
end

-- ─── Raw access ──────────────────────────────────────────────────────────────

--- Direct access to the raw data table (escape hatch).
--- @return table
function InfoDat:raw()
    return self._data
end

-- ─── Save ────────────────────────────────────────────────────────────────────

--- Write info.dat back to disk.
--- @param path string|nil  Override output path
function InfoDat:save(path)
    path = path or self._path
    local out = json.encode(self._data)
    local f   = assert(io.open(path, "w"), "BeatForge InfoDat: could not write '" .. path .. "'")
    f:write(out)
    f:close()
    print("[BeatForge] InfoDat saved → " .. path)
    return self
end

return InfoDat