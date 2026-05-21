--- BeatForge: core/wall.lua
--- Wraps a v3 obstacle raw table.

--- @class Wall
local Wall = {}
Wall.__index = Wall

function Wall.wrap(raw)
    return setmetatable({ _raw = raw }, Wall)
end

--- Create a new obstacle.
--- @param beat     number
--- @param x        integer  Column
--- @param y        integer  Row (0=bottom)
--- @param duration number   In beats
--- @param width    integer
--- @param height   integer
function Wall.new(beat, x, y, duration, width, height)
    return Wall.wrap({
        b  = beat     or 0,
        x  = x        or 0,
        y  = y        or 0,
        d  = duration or 1,
        w  = width    or 1,
        h  = height   or 1,
        customData = {},
    })
end

-- Base fields
function Wall:getBeat()     return self._raw.b end
function Wall:setBeat(v)    self._raw.b = v; return self end
function Wall:getX()        return self._raw.x end
function Wall:setX(v)       self._raw.x = v; return self end
function Wall:getY()        return self._raw.y end
function Wall:setY(v)       self._raw.y = v; return self end
function Wall:getDuration() return self._raw.d end
function Wall:setDuration(v)self._raw.d = v; return self end
function Wall:getWidth()    return self._raw.w end
function Wall:setWidth(v)   self._raw.w = v; return self end
function Wall:getHeight()   return self._raw.h end
function Wall:setHeight(v)  self._raw.h = v; return self end

local function cd(w)
    w._raw.customData = w._raw.customData or {}
    return w._raw.customData
end

local function anim(w)
    local c = cd(w)
    c.animation = c.animation or {}
    return c.animation
end

-- Noodle
function Wall:setTrack(v)          cd(self).track       = v; return self end
function Wall:setFake(v)           cd(self).fake        = v; return self end
function Wall:setInteractable(v)   cd(self).interactable= v; return self end
function Wall:setCoordinates(v)    cd(self).coordinates = v; return self end  -- {x,y}
function Wall:setWorldRotation(v)  cd(self).worldRotation = v; return self end
function Wall:setLocalRotation(v)  cd(self).localRotation = v; return self end
function Wall:setSize(v)           cd(self).size        = v; return self end  -- {w,h,d}

-- Noodle animation
function Wall:setOffsetPosition(v)      anim(self).offsetPosition      = v; return self end
function Wall:setOffsetWorldRotation(v) anim(self).offsetWorldRotation = v; return self end
function Wall:setLocalRotationAnim(v)   anim(self).localRotation       = v; return self end
function Wall:setScale(v)               anim(self).scale               = v; return self end
function Wall:setDissolve(v)            anim(self).dissolve            = v; return self end
function Wall:setDefinitePosition(v)    anim(self).definitePosition    = v; return self end
function Wall:setColor4(v)              anim(self).color               = v; return self end

-- Chroma
function Wall:setChromaColor(rgba)  cd(self).color = rgba; return self end

-- animation proxy (same pattern as note)
local animProxy_mt = {
    __newindex = function(proxy, key, value) anim(proxy._wall)[key] = value end,
    __index    = function(proxy, key)        return anim(proxy._wall)[key]  end,
}

function Wall:__index(key)
    if key == "animation" then
        return setmetatable({ _wall = self }, animProxy_mt)
    end
    return Wall[key]
end

return Wall
