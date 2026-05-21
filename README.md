# BeatForge

A lightweight Lua library for scripting Beat Saber modcharts.

```
Base Map  →  Lua Script  →  Exported Map
```

Built on the [Heck](https://github.com/Aeroluna/Heck) infrastructure (Noodle Extensions + Chroma), with a clean API inspired by [ReMapper](https://github.com/Swifter1243/ReMapper).

---

## Features

- **Lightweight** — pure Lua, zero external dependencies
- **Fast** — direct table mutation, no intermediate copies
- **Typed** — fluent setter API with clear naming conventions
- **Full Heck support** — AnimateTrack, AssignPathAnimation, AssignTrackParent, AssignPlayerToTrack
- **Full Chroma support** — colors, gradients, environment enhancements, geometry, materials, fog
- **Full Noodle support** — coordinates, localRotation, worldRotation, fake notes, point definitions, player movement
- **Animation proxy** — write `note.animation.offsetPosition = {...}` directly

---

## Installation

Copy the `beatforge/` folder into your project root. If you use [Fluxion](https://github.com/Aeroluna/Heck), drop it alongside your map files.

```
your-map/
├── beatforge/          ← library folder
│   ├── init.lua
│   ├── core/
│   ├── modules/
│   └── utils/
├── script.lua          ← your script
└── ExpertPlus.dat
```

---

## Quick Start

```lua
local bf  = require("beatforge")
local map = bf.load("ExpertPlus.dat")

-- Move all notes up by 2 units
map:notes(function(n)
    n.animation.offsetPosition = { 0, 2, 0 }
end)

-- Color every red note magenta (Chroma)
map:notes(function(n)
    if n:getColor() == 0 then
        n:setChromaColor(bf.chroma.hex("#FF00FF"))
    end
end)

map:save("ExpertPlus.dat")
```

---

## API Reference

### `bf.load(path)` / `bf.new()`

```lua
local map = bf.load("ExpertPlus.dat")  -- load existing
local map = bf.new()                   -- empty map
```

---

### Map

| Method | Description |
|--------|-------------|
| `map:notes(fn)` | Iterate all color notes |
| `map:walls(fn)` | Iterate all obstacles |
| `map:bombs(fn)` | Iterate all bomb notes |
| `map:events(fn)` | Iterate basic beat events |
| `map:filterNotes(predicate)` | Returns filtered `Note[]` |
| `map:addNote(note)` | Append a new note |
| `map:addWall(wall)` | Append a new obstacle |
| `map:addCustomEvent(ev)` | Append a Heck custom event |
| `map:addEnvironment(env)` | Append a Chroma environment entry |
| `map:setSettings(tbl)` | Set `_settings` (requirements, suggestions, modifiers) |
| `map:save(path?)` | Write to disk |

---

### Note

```lua
local Note = bf.Note
local n = Note.new(beat, x, y, color, direction)
```

**Base fields**

```lua
n:getBeat()  n:setBeat(v)
n:getX()     n:setX(v)
n:getY()     n:setY(v)
n:getColor()      -- 0=red, 1=blue
n:getDirection()  -- 0=up … 8=dot
```

**Noodle Extensions**

```lua
n:setTrack("MyTrack")
n:setFake(true)
n:setInteractable(false)
n:setCoordinates({-1.5, 0})          -- {x, y} override
n:setLocalRotation({0, 0, 45})       -- Euler degrees
n:setWorldRotation({0, 90, 0})
n:setDisableNoteLook(true)
n:setNoteJumpStartBeatOffset(-2)
```

**Animation**

```lua
-- Proxy shorthand (recommended):
n.animation.offsetPosition     = { 0, 2, 0 }
n.animation.offsetWorldRotation= {{0,0,0,0},{0,360,0,1,"easeInOutSine"}}
n.animation.dissolve           = {{0,0},{1,0.1},{1,0.9},{0,1}}
n.animation.scale              = { 2, 2, 2 }

-- Or via setters:
n:setOffsetPosition({ 0, 2, 0 })
n:setDissolve({{1,0},{0,0.8}})
```

**All animation properties**

| Property | Description |
|----------|-------------|
| `offsetPosition` | World-space translation offset |
| `offsetWorldRotation` | World-space rotation offset |
| `localPosition` | Local position |
| `localRotation` | Local rotation |
| `definitePosition` | Absolute world position (overrides spawn movement) |
| `scale` | Scale multiplier |
| `dissolve` | Note opacity (0=invisible) |
| `dissolveArrow` | Arrow opacity separately |
| `interactable` | Hit detection |
| `color` | Animated RGBA color |

**Chroma**

```lua
n:setChromaColor({1, 0, 1, 1})       -- {r,g,b,a}
n:setSpawnEffect(false)
n:setDisableDebris(true)
```

---

### Wall

```lua
local w = bf.Wall.new(beat, x, y, duration, width, height)
w:setTrack("WallTrack")
w:setFake(true)
w:setSize({3, 2, 0.1})               -- {width, height, depth}
w:setChromaColor({0, 1, 1, 0.4})
w.animation.dissolve = {{0,0},{1,0.5},{0,1}}
```

---

### Bomb

```lua
local b = bf.Bomb.new(beat, x, y)
b:setFake(true)
b:setChromaColor({1, 0.5, 0})
b.animation.offsetPosition = { 0, 3, 0 }
```

---

### Event (basic beat events / lights)

```lua
local e = bf.Event.new(beat, type, value, float)
e:setChromaColor({1, 0, 0, 1})
e:setLightID({1, 2, 3})
e:setLightGradient(bf.chroma.lightGradient(
    bf.chroma.hex("#FF0000"),
    bf.chroma.hex("#0000FF"),
    4,           -- beats
    "easeInOutSine"
))
```

---

### `bf.heck` — Custom Events

```lua
local heck = bf.heck

-- AnimateTrack: animate a named track over time
map:addCustomEvent(heck.animateTrack(
    "MyTrack",          -- track name (or table of names)
    16,                 -- beat
    {                   -- animation properties
        offsetPosition = {{0,0,0,0},{0,5,0,0.5,"easeOutSine"},{0,0,0,1}},
        scale          = { 2, 2, 2 },
    },
    8,                  -- duration in beats
    "easeInOutSine"     -- optional global easing
))

-- AssignPathAnimation: per-object lifetime animation
map:addCustomEvent(heck.assignPathAnimation(
    "BallTrack", 0,
    { definitePosition = {{-5,1,10,0},{5,1,10,1,"easeInOutSine"}} }
))

-- AssignTrackParent: parent one track under another
map:addCustomEvent(heck.assignTrackParent("ChildTrack","ParentTrack", 0))

-- AssignPlayerToTrack + animate player
map:addCustomEvent(heck.assignPlayerToTrack("PlayerTrack", 0))
map:addCustomEvent(heck.animateTrack("PlayerTrack", 8,
    { offsetPosition = {{0,0,0,0},{0,3,0,1}} }, 4
))

-- Easing constants (matches Heck string names)
heck.easing.inOutSine   -- "easeInOutSine"
heck.easing.outBounce   -- "easeOutBounce"
-- etc.
```

---

### `bf.chroma` — Chroma Helpers

```lua
local chroma = bf.chroma

-- Color constructors
chroma.rgb(1, 0, 0)              -- {1,0,0,1}
chroma.rgb255(255, 128, 0)       -- converts to 0-1
chroma.hex("#FF00FF")            -- parses hex string
chroma.hsv(0.6, 1, 1)           -- HSV to RGB
chroma.lerpColor(colorA, colorB, 0.5)

-- Color scheme (map customData)
map._data.customData.colorScheme = chroma.colorScheme(
    chroma.hex("#FF0000"),   -- left/red
    chroma.hex("#0000FF"),   -- right/blue
    chroma.hex("#880000"),   -- env left
    chroma.hex("#000088")    -- env right
)

-- Environment: target existing objects
map:addEnvironment(chroma.envPlace(
    "PillarPair\\[\\d+\\]",   -- Regex ID
    {0, 4, 20},               -- position
    {0, 0, 0},                -- rotation
    {2, 2, 2},                -- scale
    "PillarTrack"             -- optional track
))

-- Environment: geometry primitives
map:addEnvironment(chroma.envGeometry(
    "Cube",
    chroma.material("OpaqueLight", chroma.hex("#00FFFF")),
    {0, 2, 10},
    nil,
    {3, 0.1, 3},
    "FloorTrack"
))

-- Fog animation
map:addCustomEvent(chroma.fogEvent(0, 16,
    {{7,0},{3,0.5},{7,1}},  -- attenuation keyframes
    {{0,0}},                -- offset
    {{-1,0}},               -- startY
    {{6,0}}                 -- height
))

-- Light gradient
e:setLightGradient(chroma.lightGradient(
    chroma.hex("#FF0000"),
    chroma.hex("#FF00FF"),
    2,
    "easeLinear"
))
```

---

### `bf.noodle` — Noodle Utilities

```lua
local noodle = bf.noodle

-- Lane/row to Noodle coordinate system
noodle.coords(0, 0)   -- {-1.5, 0}  (lane 0, row 0)
noodle.coords(3, 2)   -- { 1.5, 2}  (lane 3, row 2)

-- Bulk track assignment
noodle.assignNoteTrack(map, "Drop", 64, 96)  -- notes between beats 64-96

-- Point definitions (reusable keyframe lists)
noodle.registerPointDef(map, "BouncePath",
    {{0,0,0,0},{0,4,0,0.5,"easeOutBounce"},{0,0,0,1,"easeInSine"}}
)
-- Then reference by name on an object:
n.animation.offsetPosition = "BouncePath"

-- Player movement (convenience wrapper)
noodle.movePlayer(map, "PlayerTrack", 16, 8,
    { offsetPosition = {{0,0,0,0},{0,3,0,1,"easeInOutCubic"}} }
)

-- _settings helpers
map:setSettings(noodle.settings.requireAll())
-- { requirements = {"Noodle Extensions", "Chroma"} }
```

---

### `bf.math` — Math & Easing

```lua
local m = bf.math

m.lerp(0, 10, 0.5)           -- 5
m.clamp(1.5, 0, 1)           -- 1
m.vecLerp({0,0,0},{1,1,1},0.5) -- {0.5,0.5,0.5}

m.ease.inOutSine(0.5)        -- Lua easing function
m.applyEasing("easeOutBounce", 0.75) -- apply by Heck name string

m.beatToSeconds(16, 120)     -- 8.0  (seconds at 120 BPM)

-- Sample a path into keyframes
local frames = m.sampleKeyframes(function(t)
    return { math.sin(t * math.pi * 2), t * 4, 0 }
end, 16, "easeLinear")
```

---

## Keyframe Format

BeatForge uses the standard Heck keyframe array format throughout:

```lua
-- Constant (no time component, single frame)
{ 0, 1, 0 }

-- Single timed keyframe
{ x, y, z, time }

-- With easing
{ x, y, z, time, "easeInOutSine" }

-- Full animation sequence
{
    { 0, 0, 0, 0 },
    { 0, 5, 0, 0.5, "easeOutSine" },
    { 0, 0, 0, 1,   "easeInSine"  },
}

-- Reference a point definition by name
"MyPointDef"
```

Time values:
- In **AnimateTrack** → beats elapsed since the event fired (0 to duration)
- In **AssignPathAnimation** → normalized note lifetime 0 → 1

---

## Examples

See the `examples/` folder:

- `examples/dissolve_entrance.lua` — Notes dissolve in from above
- `examples/spinning_walls.lua` — Walls orbit the player on a parent track  
- `examples/chroma_gradient.lua` — Hue-shifted note colors across the map

---

## Compatibility

| Feature | Mod Required |
|---------|-------------|
| `setTrack`, `AnimateTrack`, `AssignPathAnimation` | Noodle Extensions |
| `setFake`, `setCoordinates`, `setDisableNoteLook` | Noodle Extensions |
| `setChromaColor`, environment enhancements | Chroma |
| `lightGradient`, `lightID`, fog | Chroma |
| Custom events (heck module) | Heck (base) |

BeatForge outputs **v3 beatmap format** (Beat Saber 1.29+).

---

## License

MIT — do whatever you want, just don't upload broken maps.
