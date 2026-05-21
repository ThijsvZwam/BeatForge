--- BeatForge: core/event.lua
--- Wraps v3 basicBeatmapEvents with Chroma light-colour helpers.

local Event = {}
Event.__index = Event

function Event.wrap(raw)
    return setmetatable({ _raw = raw }, Event)
end

--- @param beat   number
--- @param type   integer  Light event type ID
--- @param value  integer  Light state value
--- @param float  number   Float value (brightness)
function Event.new(beat, etype, value, float)
    return Event.wrap({ b = beat or 0, et = etype or 0, i = value or 0, f = float or 1, customData = {} })
end

function Event:getBeat()    return self._raw.b  end
function Event:setBeat(v)   self._raw.b = v; return self end
function Event:getType()    return self._raw.et end
function Event:setType(v)   self._raw.et = v; return self end
function Event:getValue()   return self._raw.i  end
function Event:setValue(v)  self._raw.i = v; return self end
function Event:getFloat()   return self._raw.f  end
function Event:setFloat(v)  self._raw.f = v; return self end

local function cd(e)
    e._raw.customData = e._raw.customData or {}
    return e._raw.customData
end

--- Chroma: override light color  {r,g,b} or {r,g,b,a}
function Event:setChromaColor(rgba)     cd(self).color     = rgba; return self end
--- Chroma: light gradient  { startColor={r,g,b,a}, endColor={r,g,b,a}, duration=n, easing="easeLinear" }
function Event:setLightGradient(grad)   cd(self).lightGradient = grad; return self end
--- Chroma: target specific light IDs  {1,2,3,...}
function Event:setLightID(ids)          cd(self).lightID   = ids; return self end
--- Chroma: propID for grouped prop animations
function Event:setPropID(v)             cd(self).propID    = v; return self end
--- Chroma: lerpType  "HSV" or "RGB"
function Event:setLerpType(v)           cd(self).lerpType  = v; return self end
--- Chroma: easing for gradient events
function Event:setEasing(v)             cd(self).easing    = v; return self end

return Event
