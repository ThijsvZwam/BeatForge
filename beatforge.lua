--- BeatForge loader
--- Fetches the library from GitHub on first run, caches it locally.
--- After that works fully offline from .beatforge_cache.lua
---
--- Usage:  local bf = require("beatforge")

local CACHE  = ".beatforge_cache.lua"
local URL    = "https://raw.githubusercontent.com/ThijsvZwam/BeatForge/main/bundle.lua"
local NEEDED = "1.1.0"  -- bump this to force a re-download on next run

-- ── Try to load from cache ────────────────────────────────────────────────────

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

local function versionOf(src)
    return src and src:match('VERSION%s*=%s*"([^"]+)"')
end

local function needsUpdate(cached_ver, needed_ver)
    local function n(v)
        local a,b,c = v:match("(%d+)%.(%d+)%.(%d+)")
        return tonumber(a)*1e6 + tonumber(b)*1e3 + tonumber(c)
    end
    return n(cached_ver) < n(needed_ver)
end

local cached = readFile(CACHE)
if cached and versionOf(cached) and not needsUpdate(versionOf(cached), NEEDED) then
    return assert(load(cached, "@" .. CACHE))()
end

-- ── Download ──────────────────────────────────────────────────────────────────

io.write("[BeatForge] Downloading library from GitHub... ")
io.flush()

local function fetch(url)
    local hasCurl = io.popen("curl --version 2>&1"):read("*a"):find("curl")
    local cmd = hasCurl
        and string.format('curl -fsSL "%s"', url)
        or  string.format('wget -qO- "%s"', url)
    local p = assert(io.popen(cmd), "curl/wget not found - install either one")
    local src = p:read("*a")
    p:close()
    if not src or #src < 200 then
        return nil, "empty or invalid response"
    end
    return src
end

local src, err = fetch(URL)
if not src then
    if cached then
        print("failed, using stale cache. (" .. (err or "") .. ")")
        return assert(load(cached, "@" .. CACHE))()
    end
    error("[BeatForge] " .. (err or "download failed") .. "\nCheck the URL in beatforge.lua")
end

-- ── Write cache ───────────────────────────────────────────────────────────────

local f = io.open(CACHE, "w")
if f then f:write(src); f:close() end

print("done  (v" .. (versionOf(src) or "?") .. ")")

return assert(load(src, "@beatforge_bundle"))()
