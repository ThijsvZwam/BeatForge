# BeatForge

A tiny Lua library for scripting Beat Saber modcharts.

`Base Map` → `Lua Script` → `Exported Map`

```lua
local map = require("Noodle Extensions"),
local map = require("Chroma"),
local map = require("Fluxion"),

-- Move all notes up
map.notes(function(n) n.animation.offsetPosition = {0, 2, 0} end)

map.save("ExpertPlus.dat")
```

Lightweight: Just the scripting essentials you'll need.

Fast: Export thousands of objects in milliseconds.

Clean: Simple API for Environment and Note Data.
