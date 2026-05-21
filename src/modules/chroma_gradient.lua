--- examples/chroma_gradient.lua
--- Applies a full-map hue gradient: notes shift through the colour wheel
--- from start to finish of the map.  Works with any map.
--- Requires: Chroma

local bf     = require("beatforge")
local chroma = bf.chroma
local m      = bf.math

local map = bf.load("ExpertPlus.dat")

-- Find the beat range so we can normalise
local minBeat, maxBeat = math.huge, -math.huge
map:notes(function(n)
    local b = n:getBeat()
    if b < minBeat then minBeat = b end
    if b > maxBeat then maxBeat = b end
end)

-- Hue shift: red notes go 0°→360°, blue notes are offset by 180°
local function hueForNote(beat, isBlue)
    local t      = (beat - minBeat) / math.max(1, maxBeat - minBeat)
    local hueOff = isBlue and 0.5 or 0
    local hue    = (t + hueOff) % 1
    return chroma.hsv(hue, 1, 1)
end

map:notes(function(n)
    n:setChromaColor(hueForNote(n:getBeat(), n:getColor() == 1))
end)

-- Also tint bombs with a desaturated version of the gradient
map:bombs(function(b)
    local t   = (b:getBeat() - minBeat) / math.max(1, maxBeat - minBeat)
    local col = chroma.hsv(t, 0.5, 0.8)
    b:setChromaColor(col)
end)

-- Gradient light events to complement the notes
-- (targets event type 0 = back top laser / default environment)
local GRADIENT_STEPS = 8
local mapBeats = maxBeat - minBeat
map:events(function(e)
    if e:getType() ~= 0 then return end
    local t    = (e:getBeat() - minBeat) / math.max(1, mapBeats)
    local colA = chroma.hsv(t, 1, 1)
    local colB = chroma.hsv((t + 0.25) % 1, 1, 1)
    e:setLightGradient(chroma.lightGradient(colA, colB, 0.5, "easeLinear"))
end)

map:setSettings({ requirements = { "Chroma" } })
map:save("ExpertPlus.dat")
print(string.format(
    "Chroma gradient applied: %d beats, %.1f → %.1f",
    math.floor(mapBeats), minBeat, maxBeat
))
