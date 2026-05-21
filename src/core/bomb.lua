--- BeatForge: core/bomb.lua

local Bomb = {}
Bomb.__index = Bomb

function Bomb.wrap(raw)
    return setmetatable({ _raw = raw }, Bomb)
end

function Bomb.new(beat, x, y)
    return Bomb.wrap({ b = beat or 0, x = x or 0, y = y or 0, customData = {} })
end

function Bomb:getBeat()   return self._raw.b end
function Bomb:setBeat(v)  self._raw.b = v; return self end
function Bomb:getX()      return self._raw.x end
function Bomb:setX(v)     self._raw.x = v; return self end
function Bomb:getY()      return self._raw.y end
function Bomb:setY(v)     self._raw.y = v; return self end

local function cd(b)
    b._raw.customData = b._raw.customData or {}
    return b._raw.customData
end

local function anim(b)
    local c = cd(b)
    c.animation = c.animation or {}
    return c.animation
end

function Bomb:setTrack(v)         cd(self).track = v; return self end
function Bomb:setFake(v)          cd(self).fake  = v; return self end
function Bomb:setInteractable(v)  cd(self).interactable = v; return self end
function Bomb:setCoordinates(v)   cd(self).coordinates  = v; return self end
function Bomb:setChromaColor(v)   cd(self).color = v; return self end
function Bomb:setOffsetPosition(v)     anim(self).offsetPosition = v; return self end
function Bomb:setDissolve(v)           anim(self).dissolve       = v; return self end
function Bomb:setDefinitePosition(v)   anim(self).definitePosition = v; return self end

local animProxy_mt = {
    __newindex = function(proxy, key, value) anim(proxy._bomb)[key] = value end,
    __index    = function(proxy, key)        return anim(proxy._bomb)[key]  end,
}

function Bomb:__index(key)
    if key == "animation" then
        return setmetatable({ _bomb = self }, animProxy_mt)
    end
    return Bomb[key]
end

return Bomb
