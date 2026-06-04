--- BeatForge: core/pipeline.lua
--- Orchestrates the final map deployment pipeline:
---   • Propagates per-diff requirements/suggestions/settings into info.dat
---   • Injects Vivify bundle CRC-32 checksums automatically
---   • Copies media and untouched diffs to the output directory
---   • Optionally creates a .zip archive

local json    = require("beatforge.utils.json")
local InfoDat = require("beatforge.core.info")

--- @class Pipeline
local Pipeline = {}

-- ─── Internal OS Helpers ─────────────────────────────────────────────────────

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function writeFile(path, content)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

local function copyFile(src, dest)
    local infile = io.open(src, "rb")
    if not infile then return false end
    local outfile = io.open(dest, "wb")
    if not outfile then infile:close(); return false end
    local chunk_size = 2 ^ 13  -- 8 KB
    while true do
        local block = infile:read(chunk_size)
        if not block then break end
        outfile:write(block)
    end
    infile:close()
    outfile:close()
    return true
end

-- Normalizes paths: "./" prefix steps out of the local song folder.
local function normalizePath(path)
    if path:sub(1, 2) == "./" then
        return "../" .. path:sub(3)
    end
    return path
end

local function isWindows()
    return package.config:sub(1, 1) == "\\"
end

local function mkdir(dir)
    if isWindows() then
        os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    end
end

-- ─── Pipeline API ─────────────────────────────────────────────────────────────

--- Export the map to an output directory.
---
--- config fields:
---   outputDirectory  string    (required) Target folder
---   infoPath         string    (optional) Path to info.dat, default "info.dat"
---   vivifyBundles    table[]   (optional) { { path="windows.vivify", platform="windows" }, ... }
---                              Each bundle's CRC-32 is computed and written into info.dat.
---   zip              table     (optional) { name = "MyMapArchive" }
---
--- @param config table
function Pipeline.export(config)
    assert(config.outputDirectory, "BeatForge Pipeline: 'outputDirectory' must be specified.")

    local targetDir = normalizePath(config.outputDirectory):gsub("[/\\]+$", "")
    local infoPath  = config.infoPath or "info.dat"

    -- 1. Load info.dat via InfoDat class
    local info = InfoDat.load(infoPath)

    -- 2. Ensure output directory exists
    mkdir(targetDir)

    -- 3. Propagate per-diff settings from any loaded Map instances
    if _BF_ACTIVE_MAPS then
        info:eachDiff(function(diff)
            local filename = diff._beatmapFilename
            local boundMap = _BF_ACTIVE_MAPS[filename]
            if boundMap then
                -- Applies requirements, suggestions, settings from map._exportSettings
                info:applyMapSettings(boundMap, filename)
                -- Save the transformed diff
                boundMap:save(targetDir .. "/" .. filename)
            else
                -- Copy the untouched original diff file if it exists
                if io.open(filename, "r") then
                    copyFile(filename, targetDir .. "/" .. filename)
                end
            end
        end)
    end

    -- 4. Vivify bundle CRC injection
    --    Reads bundleinfo.json (written by the Vivify build step) and copies
    --    bundleCRCs into info.dat _customData._assetBundle.
    local bundleInfoPath = config.bundleInfoPath or "bundleinfo.json"
    if io.open(bundleInfoPath, "r") then
        info:applyBundleInfo(bundleInfoPath)
    else
        print("[BeatForge] Pipeline: no bundleinfo.json found at '" .. bundleInfoPath .. "' — skipping CRC injection")
    end

    -- 5. Sync media
    local songFile  = info:getSongFilename()
    local coverFile = info:getCoverFilename()
    if songFile  and io.open(songFile,  "rb") then copyFile(songFile,  targetDir .. "/" .. songFile)  end
    if coverFile and io.open(coverFile, "rb") then copyFile(coverFile, targetDir .. "/" .. coverFile) end

    -- 6. Save updated info.dat to output directory
    info:save(targetDir .. "/info.dat")

    print("[BeatForge] Pipeline export complete → " .. targetDir)

    -- 7. Optional zip archive
    if config.zip then
        local zipName   = config.zip.name or "MapArchive"
        local archiveDest = targetDir .. "/../" .. zipName .. ".zip"
        local cmd

        if isWindows() then
            local winTarget = targetDir:gsub("/", "\\")
            local winDest   = archiveDest:gsub("/", "\\")
            cmd = string.format(
                'powershell -Command "Compress-Archive -Path \'%s\\*\' -DestinationPath \'%s\' -Force"',
                winTarget, winDest)
        else
            cmd = string.format('cd "%s" && zip -q -r "../%s.zip" ./*', targetDir, zipName)
        end

        local success = os.execute(cmd)
        if success then
            print("[BeatForge] Archive created: " .. archiveDest)
        else
            print("[BeatForge] Warning: compression exited with unexpected code.")
        end
    end
end

--- Convenience: read bundleinfo.json and patch info.dat CRCs in-place.
--- Useful when you just want to refresh CRCs after a bundle rebuild.
--- @param bundleInfoPath string|nil  Defaults to "bundleinfo.json"
--- @param infoPath       string|nil  Defaults to "info.dat"
function Pipeline.refreshBundleCRCs(bundleInfoPath, infoPath)
    local info = InfoDat.load(infoPath or "info.dat")
    info:applyBundleInfo(bundleInfoPath or "bundleinfo.json")
    info:save()
    print("[BeatForge] CRCs refreshed in " .. (infoPath or "info.dat"))
end

return Pipeline