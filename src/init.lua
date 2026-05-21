--- BeatForge: init.lua
--- Single entry point.  Put this file at the root of your project,
--- then:   local BeatForge = require("beatforge")
---
--- The returned table exposes:
---   BeatForge.Map        — Map class
---   BeatForge.Note       — Note constructor
---   BeatForge.Wall       — Wall constructor
---   BeatForge.Bomb       — Bomb constructor
---   BeatForge.Event      — Event constructor
---   BeatForge.heck       — Heck custom-event builders
---   BeatForge.chroma     — Chroma helpers
---   BeatForge.noodle     — Noodle Extensions helpers
---   BeatForge.math       — Math / easing utilities
---
--- Quick-start (shorthand API):
---   local bf = require("beatforge")
---   local map = bf.load("ExpertPlus.dat")
---   map:notes(function(n)
---       n.animation.offsetPosition = {{0,2,0,0},{0,2,0,1,"easeOutSine"}}
---   end)
---   map:save()

-- Adjust package.path so sub-modules resolve correctly whether the library
-- is placed at project root or in a sub-folder called "beatforge/".
local info = debug.getinfo(1, "S")
local libDir = info and info.source:match("^@(.+/)") or ""
-- Allow both: require("beatforge") and require("beatforge.core.map")
package.path = libDir .. "?.lua;" .. libDir .. "?/init.lua;" .. package.path

local BeatForge = {}

-- ─── Core classes ────────────────────────────────────────────────────────────
BeatForge.Map   = require("beatforge.core.map")
BeatForge.Note  = require("beatforge.core.note")
BeatForge.Wall  = require("beatforge.core.wall")
BeatForge.Bomb  = require("beatforge.core.bomb")
BeatForge.Event = require("beatforge.core.event")

-- ─── Modules ─────────────────────────────────────────────────────────────────
BeatForge.heck   = require("beatforge.modules.heck")
BeatForge.chroma = require("beatforge.modules.chroma")
BeatForge.noodle = require("beatforge.modules.noodle")
BeatForge.math   = require("beatforge.utils.bfmath")

-- ─── Convenience top-level functions ─────────────────────────────────────────

--- Load a beatmap file and return a Map object.
--- @param path string
--- @return Map
function BeatForge.load(path)
    return BeatForge.Map.load(path)
end

--- Create an empty beatmap.
--- @return Map
function BeatForge.new()
    return BeatForge.Map.new()
end

-- ─── Version ─────────────────────────────────────────────────────────────────
BeatForge.VERSION = "1.0.0"

return BeatForge
