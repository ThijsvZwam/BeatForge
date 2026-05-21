--- BeatForge: core/pipeline.lua
--- Orchestrates the final map deployment pipeline, metadata updates,
--- folder structure cloning, and artifact distribution compression (.zip).

local json = require("beatforge.utils.json")

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
    if not outfile then infile:close() return false end
    
    local chunk_size = 2^13 -- 8KB
    while true do
        local block = infile:read(chunk_size)
        if not block then break end
        outfile:write(block)
    end
    infile:close()
    outfile:close()
    return true
end

-- Normalizes paths relative to parent spaces. If the string begins with './',
-- it steps out of the local song folder into CustomWIPLevels.
local function normalizePath(path)
    if path:sub(1, 2) == "./" then
        return "../" .. path:sub(3)
    end
    return path
end

-- ─── Pipeline API ────────────────────────────────────────────────────────────

--- Run deployment sequences across active map instances.
--- @param config table Interface configuration object
function Pipeline.export(config)
    assert(config.outputDirectory, "BeatForge Pipeline: 'outputDirectory' must be specified.")
    
    local targetDir = normalizePath(config.outputDirectory):gsub("[/\\]+$", "")
    local sourceInfoPath = "info.dat"
    
    -- 1. Read local base layout configuration
    local infoRaw = readFile(sourceInfoPath)
    if not infoRaw then
        error("BeatForge Pipeline: Could not find baseline map configuration metadata layout 'info.dat'.")
    end
    local infoData = json.decode(infoRaw)

    -- Ensure target directory structural workspace exists safely
    local isWindows = package.config:sub(1,1) == "\\"
    if isWindows then
        os.execute('mkdir "' .. targetDir:gsub("/", "\\") .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. targetDir .. '" 2>/dev/null')
    end

    -- 2. Process requirement configurations across loaded active difficulty maps
    if _BF_ACTIVE_MAPS and infoData._difficultyBeatmapSets then
        for _, set in ipairs(infoData._difficultyBeatmapSets) do
            for _, diff in ipairs(set._difficultyBeatmaps) do
                local filename = diff._beatmapFilename
                local boundMap = _BF_ACTIVE_MAPS[filename]

                if boundMap then
                    diff._customData = diff._customData or {}
                    
                    -- Extract configuration rules handled during script execution
                    if boundMap._exportSettings then
                        if boundMap._exportSettings.requirements then
                            diff._customData._requirements = boundMap._exportSettings.requirements
                        end
                        if boundMap._exportSettings.suggestions then
                            diff._customData._suggestions = boundMap._exportSettings.suggestions
                        end
                        if boundMap._exportSettings.settings then
                            diff._customData._settings = boundMap._exportSettings.settings
                        end
                    end

                    -- Save the transformed difficulty payload into target location
                    boundMap:save(targetDir .. "/" .. filename)
                else
                    -- Copy untouched original map file if not targeted by current lua script execution pass
                    if io.open(filename, "r") then
                        copyFile(filename, targetDir .. "/" .. filename)
                    end
                end
            end
        end
    end

    -- 3. Sync media resource targets
    local songFilename  = infoData._songFilename
    local coverFilename = infoData._coverImageFilename

    if songFilename  then copyFile(songFilename,  targetDir .. "/" .. songFilename)  end
    if coverFilename then copyFile(coverFilename, targetDir .. "/" .. coverFilename) end

    -- 4. Dump updated manifest mapping configuration properties
    writeFile(targetDir .. "/info.dat", json.encode(infoData))
    print("[BeatForge] Map workspace deployment generated at target directory location: " .. targetDir)

    -- 5. Optional compression archive configuration
    if config.zip then
        local zipName = config.zip.name or "MapArchive"
        local archiveDest = targetDir .. "/../" .. zipName .. ".zip"
        local cmd
        
        if isWindows then
            -- Use PowerShell to create zip on Windows platforms natively
            local winTarget = targetDir:gsub("/", "\\")
            local winDest   = archiveDest:gsub("/", "\\")
            cmd = string.format('powershell -Command "Compress-Archive -Path \'%s\\*\' -DestinationPath \'%s\' -Force"', winTarget, winDest)
        else
            -- Standard Posix compression sequence
            cmd = string.format('cd "%s" && zip -q -r "../%s.zip" ./*', targetDir, zipName)
        end
        
        local success = os.execute(cmd)
        if success then
            print("[BeatForge] Successfully created map zip file package at: " .. archiveDest)
        else
            print("[BeatForge] Warning: Native workspace compression tasks exited with unexpected codes.")
        end
    end
end

return Pipeline