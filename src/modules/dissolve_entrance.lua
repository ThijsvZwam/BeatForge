--- examples/dissolve_entrance.lua
--- Notes dissolve in from 2 units above over the first half of
--- their approach, then settle into their real position.
--- Requires: Noodle Extensions

local bf  = require("beatforge")
local map = bf.load("ExpertPlus.dat")

map:notes(function(n)
    -- Each note spawns 2 units up, drops to normal position by t=0.3
    n.animation.offsetPosition = {
        { 0,  2, 0, 0                   },
        { 0,  0, 0, 0.3, "easeOutSine"  },
    }

    -- Fade from invisible to full opacity between t=0 and t=0.25
    n.animation.dissolve = {
        { 0, 0                      },
        { 1, 0.25, "easeOutQuad"   },
    }

    -- Also fade the arrow in slightly later
    n.animation.dissolveArrow = {
        { 0, 0                      },
        { 1, 0.4, "easeOutSine"    },
    }
end)

map:save("ExpertPlus.dat")
print("Done: dissolve entrance applied to all notes.")
