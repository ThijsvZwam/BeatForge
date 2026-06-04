--- BeatForge: modules/vivify.lua
--- Builders for Vivify custom event types.
---
--- Vivify is Aeroluna's visual extension to Heck that lets mappers
--- control GameObject prefabs, materials, renderer properties, and
--- post-processing through custom events.
---
--- All events are raw tables suitable for map:addCustomEvent().
---
--- Reference: https://github.com/Aeroluna/Vivify

local vivify = {}

-- ─── Event type constants ─────────────────────────────────────────────────────

vivify.type = {
    SetMaterialProperty     = "SetMaterialProperty",
    SetGlobalProperty       = "SetGlobalProperty",
    AssignObjectPrefab      = "AssignObjectPrefab",
    AssignTrackPrefab       = "AssignTrackPrefab",
    DestroyObject           = "DestroyObject",
    InstantiateObject       = "InstantiateObject",
    SetAnimatorProperty     = "SetAnimatorProperty",
    AssignFogTrack          = "AssignFogTrack",
    SetRenderingSettings    = "SetRenderingSettings",
    SetCameraProperty       = "SetCameraProperty",
    CreateScreenTexture     = "CreateScreenTexture",
    DestroyScreenTexture    = "DestroyScreenTexture",
}

-- ─── AssignObjectPrefab ───────────────────────────────────────────────────────
-- Spawns a bundle prefab and assigns it to a track (or to note/wall objects).

--- Assign a prefab from the bundle to a Heck track or to note/wall objects.
--- @param beat      number
--- @param loadMode  string  "Single"|"Additive"|"AdditiveAddend"|"Subtract"
--- @param assets    table[]  Array of { bundle=str, prefab=str, track=str }
---                           `track` here is the Vivify "object track" to use as the
---                           attachment point; optional – omit to attach to the named
---                           Heck track directly.
--- @return table
function vivify.assignObjectPrefab(beat, loadMode, assets)
    return {
        b = beat,
        t = "AssignObjectPrefab",
        d = {
            loadMode = loadMode or "Single",
            assets   = assets,
        },
    }
end

--- Shorthand: spawn one prefab on a track.
--- @param beat    number
--- @param bundle  string  Bundle filename (no path, e.g. "windows")
--- @param prefab  string  Asset path inside the bundle
--- @param track   string  Heck track name to attach to
--- @param loadMode string|nil  Defaults to "Single"
--- @return table
function vivify.spawnPrefab(beat, bundle, prefab, track, loadMode)
    return vivify.assignObjectPrefab(beat, loadMode or "Single", {
        { bundle = bundle, prefab = prefab, track = track },
    })
end

--- Destroy/unload all prefabs on a track (pass an empty assets list).
--- @param beat   number
--- @param track  string
--- @return table
function vivify.destroyPrefab(beat, track)
    return {
        b = beat,
        t = "AssignObjectPrefab",
        d = {
            loadMode = "Single",
            assets   = {},
            track    = track,
        },
    }
end

-- ─── AssignTrackPrefab ────────────────────────────────────────────────────────
-- Binds a prefab to every note/wall that spawns on a specific track.
-- The prefab replaces or augments the default note mesh.

--- @param beat   number
--- @param track  string  Heck track
--- @param bundle string  Bundle filename
--- @param prefab string  Asset path inside bundle
--- @return table
function vivify.assignTrackPrefab(beat, track, bundle, prefab)
    return {
        b = beat,
        t = "AssignTrackPrefab",
        d = {
            track  = track,
            bundle = bundle,
            prefab = prefab,
        },
    }
end

-- ─── SetMaterialProperty ─────────────────────────────────────────────────────
-- Set a shader property on a material that is on a Vivify-managed renderer.

--- @param beat     number
--- @param asset    string  Material asset path or renderer track
--- @param properties table[]  Array of { name=str, type=str, value=any }
---                            type: "Float","Int","Color","Vector","Keyword","Texture"
--- @param duration number|nil
--- @param easing   string|nil
--- @return table
function vivify.setMaterialProperty(beat, asset, properties, duration, easing)
    local d = {
        asset      = asset,
        properties = properties,
    }
    if duration then d.duration = duration end
    if easing   then d.easing   = easing   end
    return { b = beat, t = "SetMaterialProperty", d = d }
end

--- Shorthand: animate a single float property.
--- @param beat     number
--- @param asset    string
--- @param name     string   Shader property name
--- @param value    number|table  Constant or keyframe list
--- @param duration number|nil
--- @param easing   string|nil
--- @return table
function vivify.setFloat(beat, asset, name, value, duration, easing)
    return vivify.setMaterialProperty(beat, asset,
        { { name = name, type = "Float", value = value } },
        duration, easing)
end

--- Shorthand: animate a color property.
--- @param beat     number
--- @param asset    string
--- @param name     string
--- @param color    number[]|table  {r,g,b,a} or keyframe list
--- @param duration number|nil
--- @param easing   string|nil
--- @return table
function vivify.setColor(beat, asset, name, color, duration, easing)
    return vivify.setMaterialProperty(beat, asset,
        { { name = name, type = "Color", value = color } },
        duration, easing)
end

-- ─── SetGlobalProperty ───────────────────────────────────────────────────────
-- Like SetMaterialProperty but targets Shader.SetGlobal* — affects all materials.

--- @param beat       number
--- @param properties table[]
--- @param duration   number|nil
--- @param easing     string|nil
--- @return table
function vivify.setGlobalProperty(beat, properties, duration, easing)
    local d = { properties = properties }
    if duration then d.duration = duration end
    if easing   then d.easing   = easing   end
    return { b = beat, t = "SetGlobalProperty", d = d }
end

-- ─── SetAnimatorProperty ─────────────────────────────────────────────────────

--- Set an Animator parameter on a Vivify-managed animator.
--- @param beat       number
--- @param track      string  Vivify object track with an Animator component
--- @param properties table[]  { name=str, type="Float"|"Int"|"Bool"|"Trigger", value=any }
--- @param duration   number|nil
--- @param easing     string|nil
--- @return table
function vivify.setAnimatorProperty(beat, track, properties, duration, easing)
    local d = { track = track, properties = properties }
    if duration then d.duration = duration end
    if easing   then d.easing   = easing   end
    return { b = beat, t = "SetAnimatorProperty", d = d }
end

-- ─── AssignFogTrack ───────────────────────────────────────────────────────────
-- Assigns a Heck track to control Beat Saber's height fog parameters.
-- Properties animatable via AnimateTrack: attenuation, offset, startY, height.

--- @param beat  number
--- @param track string  Heck track name that will drive fog
--- @return table
function vivify.assignFogTrack(beat, track)
    return {
        b = beat,
        t = "AssignFogTrack",
        d = { track = track },
    }
end

--- Convenience: assign fog track and return an AnimateTrack event for it.
--- Returns TWO events as a pair: {assignEvent, animateEvent}
--- Insert both with map:addCustomEvent.
--- @param map      Map     used to add the assign event immediately
--- @param track    string
--- @param beat     number  When to start animating fog
--- @param duration number
--- @param fogProps table   { attenuation=..., offset=..., startY=..., height=... }
--- @param easing   string|nil
--- @return table  The AnimateTrack event (assign event is already added to map)
function vivify.animateFog(map, track, beat, duration, fogProps, easing)
    local heck = require("beatforge.modules.heck")
    -- Assign the fog track at beat 0 (idempotent — multiple calls are fine)
    map:addCustomEvent(vivify.assignFogTrack(0, track))
    -- Return the AnimateTrack event for the caller to add (or add it here)
    local ev = heck.animateTrack(track, beat, fogProps, duration, easing)
    map:addCustomEvent(ev)
    return ev
end

-- ─── InstantiateObject / DestroyObject ───────────────────────────────────────

--- Instantiate a prefab at a world position (not track-bound).
--- @param beat     number
--- @param bundle   string
--- @param prefab   string
--- @param id       string  Unique ID used to reference/destroy later
--- @param position number[]|nil  {x,y,z}
--- @param rotation number[]|nil  {x,y,z} Euler
--- @param scale    number[]|nil  {x,y,z}
--- @return table
function vivify.instantiate(beat, bundle, prefab, id, position, rotation, scale)
    local d = { bundle = bundle, prefab = prefab, id = id }
    if position then d.position = position end
    if rotation then d.rotation = rotation end
    if scale    then d.scale    = scale    end
    return { b = beat, t = "InstantiateObject", d = d }
end

--- Destroy an object previously instantiated with vivify.instantiate.
--- @param beat number
--- @param id   string
--- @return table
function vivify.destroy(beat, id)
    return { b = beat, t = "DestroyObject", d = { id = id } }
end

-- ─── SetRenderingSettings ────────────────────────────────────────────────────
-- Control Unity rendering/camera settings at runtime.

--- @param beat     number
--- @param settings table  Key-value pairs of rendering settings
---   Common keys: bloomIntensity, vignetteIntensity, vignetteColor,
---                dof_focusDistance, dof_aperture, ambientIntensity
--- @param duration number|nil
--- @param easing   string|nil
--- @return table
function vivify.setRenderingSettings(beat, settings, duration, easing)
    local d = {}
    for k, v in pairs(settings) do d[k] = v end
    if duration then d.duration = duration end
    if easing   then d.easing   = easing   end
    return { b = beat, t = "SetRenderingSettings", d = d }
end

-- ─── Screen textures (render-to-texture) ─────────────────────────────────────

--- Create a screen-space render texture and give it a name.
--- @param beat       number
--- @param name       string  Identifier used in shader _MainTex / global samplers
--- @param width      integer|nil  Defaults to screen width
--- @param height     integer|nil  Defaults to screen height
--- @param depthBits  integer|nil  0, 16, 24 (default 0)
--- @return table
function vivify.createScreenTexture(beat, name, width, height, depthBits)
    local d = { name = name }
    if width     then d.width     = width     end
    if height    then d.height    = height    end
    if depthBits then d.depthBits = depthBits end
    return { b = beat, t = "CreateScreenTexture", d = d }
end

--- Destroy a screen texture created with createScreenTexture.
--- @param beat number
--- @param name string
--- @return table
function vivify.destroyScreenTexture(beat, name)
    return { b = beat, t = "DestroyScreenTexture", d = { name = name } }
end

-- ─── Property type helpers ───────────────────────────────────────────────────
-- Convenience constructors for the `properties` array entries.

--- Float property entry.
function vivify.propFloat(name, value)
    return { name = name, type = "Float", value = value }
end

--- Int property entry.
function vivify.propInt(name, value)
    return { name = name, type = "Int", value = value }
end

--- Color property entry.  value is {r,g,b,a} or keyframe list.
function vivify.propColor(name, value)
    return { name = name, type = "Color", value = value }
end

--- Vector property entry.  value is {x,y,z,w} or keyframe list.
function vivify.propVector(name, value)
    return { name = name, type = "Vector", value = value }
end

--- Keyword (shader keyword toggle) property entry.
function vivify.propKeyword(name, value)
    return { name = name, type = "Keyword", value = value }
end

--- Texture property entry.  value is a screen-texture name string.
function vivify.propTexture(name, value)
    return { name = name, type = "Texture", value = value }
end

-- ─── Load mode constants ─────────────────────────────────────────────────────

vivify.loadMode = {
    Single        = "Single",        -- replace any existing prefab on the track
    Additive      = "Additive",      -- add alongside existing prefabs
    AdditiveAddend= "AdditiveAddend",-- add but share parent transform
    Subtract      = "Subtract",      -- remove matching prefab type
}

-- ─── Platform constants ───────────────────────────────────────────────────────
-- Used in info.dat bundle entries (InfoDat:addVivifyBundle).

vivify.platform = {
    Windows = "windows",
    Android = "android",
}

return vivify
