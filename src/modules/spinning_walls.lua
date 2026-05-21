--- examples/spinning_walls.lua
--- Creates 6 thin "blade" walls evenly distributed around the player,
--- parents them to a single track, then slowly rotates that track.
--- Requires: Noodle Extensions

local bf    = require("beatforge")
local heck  = bf.heck
local m     = bf.math
local Wall  = bf.Wall

local map   = bf.new()   -- generative: start from scratch

local TRACK     = "OrbitRing"
local BLADES    = 6
local RADIUS    = 3.5    -- units from centre
local START     = 0      -- beat
local DURATION  = 64     -- beat range

-- ── Create walls ──────────────────────────────────────────────────────────────

for i = 0, BLADES - 1 do
    local angle  = (i / BLADES) * 360   -- degrees
    local rad    = math.rad(angle)
    local cx     = math.cos(rad) * RADIUS
    local cy     = math.sin(rad) * RADIUS

    local w = Wall.new(START, 0, 0, DURATION, 1, 1)
    w:setFake(true)
    w:setInteractable(false)
    w:setTrack(TRACK)
    w:setCoordinates({ cx, cy })           -- place around ring
    w:setSize({ 0.15, 2, 0.15 })          -- thin blade
    w:setLocalRotation({ 0, 0, angle })   -- orient outward
    w:setChromaColor({ 0.2, 0.8, 1, 0.6 })

    -- Dissolve in/out at the edges of the section
    w.animation.dissolve = {
        { 0, 0               },
        { 1, 0.05, "easeOutSine" },
        { 1, 0.95            },
        { 0, 1,   "easeInSine" },
    }

    map:addWall(w)
end

-- ── Rotate the parent track ───────────────────────────────────────────────────

map:addCustomEvent(heck.animateTrack(
    TRACK, START,
    {
        offsetWorldRotation = {
            { 0,   0, 0, 0               },
            { 0, 360, 0, 1, "easeLinear" },
        },
    },
    DURATION
))

-- ── Requirements ─────────────────────────────────────────────────────────────

map:setSettings({ requirements = { "Noodle Extensions" } })
map:save("ExpertPlusGenerated.dat")
print(string.format("Created %d orbital walls over %d beats.", BLADES, DURATION))
