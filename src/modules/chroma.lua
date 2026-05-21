--- BeatForge: modules/chroma.lua
--- Helpers for Chroma-specific features:
---   • Color construction utilities
---   • Environment enhancement builders
---   • Chroma light event builders (boost, gradient, fog)

local chroma = {}

-- ─── Color utilities ─────────────────────────────────────────────────────────

--- Build an RGB color table (0-1 range per channel).
--- @param r number
--- @param g number
--- @param b number
--- @param a number|nil  Alpha, default 1
--- @return number[]
function chroma.rgb(r, g, b, a)
    return { r, g, b, a or 1 }
end

--- Convert 0-255 integer channels to 0-1 table.
--- @return number[]
function chroma.rgb255(r, g, b, a)
    return { r / 255, g / 255, b / 255, (a or 255) / 255 }
end

--- Convert a hex color string "#RRGGBB" or "#RRGGBBAA" to a {r,g,b,a} table.
--- @param hex string
--- @return number[]
function chroma.hex(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1,2), 16) / 255
    local g = tonumber(hex:sub(3,4), 16) / 255
    local b = tonumber(hex:sub(5,6), 16) / 255
    local a = hex:len() >= 8 and tonumber(hex:sub(7,8), 16) / 255 or 1
    return { r, g, b, a }
end

--- Convert HSV (0-1 range) to an RGB {r,g,b,1} table.
--- @param h number  Hue 0-1
--- @param s number  Saturation 0-1
--- @param v number  Value/brightness 0-1
--- @return number[]
function chroma.hsv(h, s, v)
    if s == 0 then return { v, v, v, 1 } end
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local r, g, b
    i = i % 6
    if i == 0 then r,g,b = v,t,p
    elseif i == 1 then r,g,b = q,v,p
    elseif i == 2 then r,g,b = p,v,t
    elseif i == 3 then r,g,b = p,q,v
    elseif i == 4 then r,g,b = t,p,v
    else               r,g,b = v,p,q
    end
    return { r, g, b, 1 }
end

--- Linearly interpolate between two {r,g,b,a} colors.
--- @param a number[]
--- @param b number[]
--- @param t number   0-1
--- @return number[]
function chroma.lerpColor(a, b, t)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
        (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t,
    }
end

-- ─── Colour scheme (sabers / notes / environment) ────────────────────────────

--- Build a Chroma _colorScheme block for map customData.
--- Pass nil for any color you want to leave at default.
--- @param colorLeft  number[]|nil  Left saber / red note color
--- @param colorRight number[]|nil  Right saber / blue note color
--- @param envLeft    number[]|nil  Environment left color
--- @param envRight   number[]|nil  Environment right color
--- @param obstacleColor number[]|nil
--- @return table
function chroma.colorScheme(colorLeft, colorRight, envLeft, envRight, obstacleColor)
    local s = {}
    if colorLeft     then s.colorLeft     = colorLeft     end
    if colorRight    then s.colorRight    = colorRight    end
    if envLeft       then s.envColorLeft  = envLeft       end
    if envRight      then s.envColorRight = envRight      end
    if obstacleColor then s.obstacleColor = obstacleColor end
    return s
end

-- ─── Environment enhancements ────────────────────────────────────────────────
-- These go into map customData.environment[]

--- Target an environment component by regex ID or geometry.
--- @param id       string        GameObject name/regex
--- @param lookupMethod string    "Regex","Exact","Contains","StartsWith","EndsWith" (default "Regex")
--- @return table  Partial env object, add fields then pass to map:addEnvironment()
function chroma.envTarget(id, lookupMethod)
    return { id = id, lookupMethod = lookupMethod or "Regex" }
end

--- Convenience: duplicate an env object and position it.
--- @param id       string
--- @param position number[]  {x,y,z}
--- @param rotation number[]|nil  {x,y,z} Euler
--- @param scale    number[]|nil  {x,y,z}
--- @param track    string|nil
--- @return table
function chroma.envPlace(id, position, rotation, scale, track)
    local e = {
        id           = id,
        lookupMethod = "Regex",
        position     = position,
    }
    if rotation then e.rotation = rotation end
    if scale    then e.scale    = scale    end
    if track    then e.track    = track    end
    return e
end

--- Build a geometry (primitive) environment object.
--- @param shape     string  "Sphere","Capsule","Cylinder","Cube","Plane","Quad","Triangle"
--- @param material  table   { shader=..., color=..., track=... }
--- @param position  number[]
--- @param rotation  number[]|nil
--- @param scale     number[]|nil
--- @param track     string|nil
--- @return table
function chroma.envGeometry(shape, material, position, rotation, scale, track)
    local e = {
        geometry = {
            type     = shape,
            material = material,
        },
        position = position,
    }
    if rotation then e.rotation = rotation end
    if scale    then e.scale    = scale    end
    if track    then e.track    = track    end
    return e
end

--- Build a Chroma material table.
--- @param shader string  "Standard","OpaqueLight","TransparentLight","BaseWater","BillieWater","BTSPillar","InterscopeConcrete","InterscopeCar","Obstacle","WaterfallMirror"
--- @param color  number[]|nil
--- @param shaderKeywords string[]|nil
--- @return table
function chroma.material(shader, color, shaderKeywords)
    local m = { shader = shader }
    if color          then m.color          = color          end
    if shaderKeywords then m.shaderKeywords = shaderKeywords end
    return m
end

-- ─── Light gradient helper ───────────────────────────────────────────────────

--- Build a Chroma lightGradient block for use in event:setLightGradient().
--- @param startColor number[]
--- @param endColor   number[]
--- @param duration   number   Beats
--- @param easing     string|nil  (default "easeLinear")
--- @return table
function chroma.lightGradient(startColor, endColor, duration, easing)
    return {
        startColor = startColor,
        endColor   = endColor,
        duration   = duration,
        easing     = easing or "easeLinear",
    }
end

-- ─── Fog (Chroma/Heck) ───────────────────────────────────────────────────────

--- Build a fog customEvent (AnimateTrack targeting the "FogTrack" reserved track).
--- @param beat     number
--- @param duration number   Beats
--- @param attenuation  number|table  Keyframed or constant
--- @param offset       number|table
--- @param startY       number|table
--- @param height       number|table
--- @return table  Raw custom event
function chroma.fogEvent(beat, duration, attenuation, offset, startY, height)
    return {
        b = beat,
        t = "AnimateTrack",
        d = {
            track       = "FogTrack",  -- reserved Chroma fog track
            duration    = duration,
            attenuation = attenuation,
            offset      = offset,
            startY      = startY,
            height      = height,
        },
    }
end

return chroma
