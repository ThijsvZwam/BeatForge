--- examples/vivify_example.lua
--- Demonstrates:
---   • Spawning a Vivify prefab on a track
---   • Animating a material property
---   • Fog animation via assignFogTrack
---   • Full pipeline export with automatic bundle CRC injection
---
--- Requires: Noodle Extensions, Chroma, Vivify

local bf     = require("beatforge")
local heck   = bf.heck
local vivify = bf.vivify
local chroma = bf.chroma

local map = bf.load("ExpertPlus.dat")

-- ── 1. Spawn a crystal prefab on the "CrystalTrack" Heck track ───────────────
-- The prefab replaces/augments notes that have been assigned to this track.
-- Notes on "CrystalTrack" will wear the custom mesh from the bundle.

bf.noodle.assignNoteTrack(map, "CrystalTrack", 0, 999)

-- Assign the prefab from the "windows" bundle (platform-specific filename):
map:addCustomEvent(vivify.spawnPrefab(
    0,               -- beat
    "windows",       -- bundle key (matched to bundle filename in info.dat)
    "Assets/Prefabs/CrystalNote.prefab",
    "CrystalTrack",
    vivify.loadMode.Single
))

-- ── 2. Pulse the crystal's emission intensity via a material property ─────────
-- SetMaterialProperty targets the material on the prefab renderer.

map:addCustomEvent(vivify.setFloat(
    32,                             -- beat
    "Assets/Materials/Crystal.mat", -- material asset path inside bundle
    "_EmissionIntensity",           -- shader property name
    {                               -- keyframes: value, time [, easing]
        { 0,   0               },
        { 8,   0.5, "easeOutSine" },
        { 0,   1,   "easeInSine"  },
    },
    16,                             -- duration in beats
    nil                             -- no global easing override
))

-- ── 3. Animated fog via AssignFogTrack ────────────────────────────────────────
-- vivify.animateFog adds both the AssignFogTrack and AnimateTrack events.

vivify.animateFog(map, "FogTrack",
    64,     -- beat to start animating
    32,     -- duration in beats
    {       -- fog AnimateTrack properties
        attenuation = { {7,0}, {2, 0.3, "easeOutSine"}, {7, 1, "easeInSine"} },
        height      = { {6,0}, {12, 0.5, "easeOutQuad"}, {6, 1, "easeInQuad"} },
        startY      = { {-1, 0} },   -- constant
        offset      = { {0,  0} },
    }
)

-- ── 4. Rotating orbit ring of walls (same as spinning_walls example) ──────────
-- Kept minimal here — see spinning_walls.lua for the full version.

-- ── 5. Requirements / settings ───────────────────────────────────────────────
map:setSettings({
    requirements = { "Noodle Extensions", "Chroma", "Vivify" },
})

map:save("ExpertPlus.dat")

-- ── 6. Full pipeline export with Vivify bundle CRC auto-injection ─────────────
--
-- The pipeline will:
--   a) Load info.dat
--   b) Propagate requirements into the correct diff block in info.dat
--   c) Compute CRC-32 for each bundle file and write it into info.dat customData._vivify
--   d) Copy bundles, song, cover to the output directory
--   e) Save the updated info.dat

bf.pipeline.export({
    outputDirectory = "./output",

    -- List all your Vivify bundles here.
    -- CRCs are computed automatically from the files on disk.
    vivifyBundles = {
        { path = "windows.vivify", platform = vivify.platform.Windows },
        { path = "android.vivify", platform = vivify.platform.Android },
    },

    -- Optional: create a distributable zip
    zip = { name = "MyCoolMap" },
})

--[[
  After export, info.dat will contain something like:

  "_customData": {
    "_vivify": {
      "bundles": [
        { "filename": "windows.vivify", "checksum": 3851234567, "platform": "windows" },
        { "filename": "android.vivify", "checksum": 1234098765, "platform": "android" }
      ]
    }
  }

  And ExpertPlus.dat's diff block in info.dat will contain:
  "_customData": {
    "_requirements": ["Chroma", "Noodle Extensions", "Vivify"]
  }
--]]

print("Done! Check ./output/")
