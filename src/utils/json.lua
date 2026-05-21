--- BeatForge: utils/json.lua
--- Minimal JSON encoder/decoder (pure Lua, no dependencies).
--- Handles numbers, strings, booleans, nil, arrays, and objects.
--- Preserves numeric precision up to Lua's double range.

local json = {}

-- ─── Decode ──────────────────────────────────────────────────────────────────

local function skipWhitespace(s, pos)
    return s:match("^%s*()", pos)
end

local function parseValue(s, pos)  -- forward declaration
end

local function parseString(s, pos)
    -- pos is at opening '"'
    local result = {}
    local i = pos + 1
    while i <= #s do
        local c = s:sub(i, i)
        if c == '"' then
            return table.concat(result), i + 1
        elseif c == '\\' then
            local esc = s:sub(i+1, i+1)
            if esc == '"'  then table.insert(result, '"')
            elseif esc == '\\' then table.insert(result, '\\')
            elseif esc == '/'  then table.insert(result, '/')
            elseif esc == 'n'  then table.insert(result, '\n')
            elseif esc == 'r'  then table.insert(result, '\r')
            elseif esc == 't'  then table.insert(result, '\t')
            elseif esc == 'b'  then table.insert(result, '\b')
            elseif esc == 'f'  then table.insert(result, '\f')
            elseif esc == 'u'  then
                local hex = s:sub(i+2, i+5)
                local cp  = tonumber(hex, 16) or 0
                if cp < 0x80 then
                    table.insert(result, string.char(cp))
                elseif cp < 0x800 then
                    table.insert(result, string.char(0xC0 + math.floor(cp/64), 0x80 + cp%64))
                else
                    table.insert(result, string.char(
                        0xE0 + math.floor(cp/4096),
                        0x80 + math.floor(cp/64)%64,
                        0x80 + cp%64))
                end
                i = i + 4
            end
            i = i + 2
        else
            table.insert(result, c)
            i = i + 1
        end
    end
    error("JSON: unterminated string near position " .. pos)
end

local function parseArray(s, pos)
    local arr = {}
    pos = skipWhitespace(s, pos + 1)
    if s:sub(pos, pos) == ']' then return arr, pos + 1 end
    while true do
        local val
        val, pos = parseValue(s, pos)
        table.insert(arr, val)
        pos = skipWhitespace(s, pos)
        local c = s:sub(pos, pos)
        if c == ']' then return arr, pos + 1 end
        if c ~= ',' then error("JSON: expected ',' or ']' at position " .. pos) end
        pos = skipWhitespace(s, pos + 1)
    end
end

local function parseObject(s, pos)
    local obj = {}
    pos = skipWhitespace(s, pos + 1)
    if s:sub(pos, pos) == '}' then return obj, pos + 1 end
    while true do
        if s:sub(pos, pos) ~= '"' then
            error("JSON: expected string key at position " .. pos)
        end
        local key
        key, pos = parseString(s, pos)
        pos = skipWhitespace(s, pos)
        if s:sub(pos, pos) ~= ':' then
            error("JSON: expected ':' at position " .. pos)
        end
        pos = skipWhitespace(s, pos + 1)
        local val
        val, pos = parseValue(s, pos)
        obj[key] = val
        pos = skipWhitespace(s, pos)
        local c = s:sub(pos, pos)
        if c == '}' then return obj, pos + 1 end
        if c ~= ',' then error("JSON: expected ',' or '}' at position " .. pos) end
        pos = skipWhitespace(s, pos + 1)
    end
end

parseValue = function(s, pos)
    pos = skipWhitespace(s, pos)
    local c = s:sub(pos, pos)
    if c == '"' then
        return parseString(s, pos)
    elseif c == '{' then
        return parseObject(s, pos)
    elseif c == '[' then
        return parseArray(s, pos)
    elseif c == 't' then
        assert(s:sub(pos, pos+3) == "true"); return true, pos + 4
    elseif c == 'f' then
        assert(s:sub(pos, pos+4) == "false"); return false, pos + 5
    elseif c == 'n' then
        assert(s:sub(pos, pos+3) == "null"); return nil, pos + 4  -- becomes nil key gap
    else
        local num, next = s:match("^(-?%d+%.?%d*[eE]?[+-]?%d*)()", pos)
        if num then return tonumber(num), next end
        error("JSON: unexpected character '" .. c .. "' at position " .. pos)
    end
end

--- Decode a JSON string into a Lua value.
--- @param s string
--- @return any
function json.decode(s)
    local val, _ = parseValue(s, 1)
    return val
end

-- ─── Encode ──────────────────────────────────────────────────────────────────

local ESC = {
    ['"']  = '\\"',
    ['\\'] = '\\\\',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
}

local function encodeString(s)
    return '"' .. s:gsub('[%z\1-\31"\\]', function(c)
        return ESC[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
end

local function isArray(t)
    -- A table is an array when all keys are consecutive integers from 1
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return n > 0 or next(t) == nil
end

local function encodeValue(v, indent, indentStr)
    local ty = type(v)
    if ty == "nil"     then return "null"
    elseif ty == "boolean" then return tostring(v)
    elseif ty == "number"  then
        if v ~= v then return "null" end      -- NaN guard
        if v == math.huge or v == -math.huge then return "null" end
        -- Omit trailing .0 for integers
        if math.floor(v) == v and math.abs(v) < 1e15 then
            return string.format("%d", v)
        end
        return string.format("%.10g", v)
    elseif ty == "string" then
        return encodeString(v)
    elseif ty == "table"  then
        if isArray(v) then
            local parts = {}
            for _, item in ipairs(v) do
                table.insert(parts, encodeValue(item, indent, indentStr))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            -- Sort keys for deterministic output
            local keys = {}
            for k in pairs(v) do table.insert(keys, k) end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            for _, k in ipairs(keys) do
                local encoded = encodeValue(v[k], indent, indentStr)
                if encoded ~= "null" or v[k] ~= nil then
                    table.insert(parts, encodeString(tostring(k)) .. ":" .. encoded)
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return "null"
    end
end

--- Encode a Lua value to a JSON string.
--- @param v any
--- @return string
function json.encode(v)
    return encodeValue(v, 0, "  ")
end

return json
