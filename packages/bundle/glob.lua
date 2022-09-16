local fs = require "filesystem"

local PathSeq <const> = '/'

local MATCH_SUCCESS <const> = 0
local MATCH_PENDING <const> = 1
local MATCH_FAILED <const> = 2
local MATCH_SKIP <const> = 3

local GlobStar <const> = 0

local function join(...)
    return table.concat(table.pack(...), '/')
end

local function normalize(...)
    local fullname = join(...)
    if fullname == "/" then
        return "/"
    end
    local first = (fullname:sub(1, 1) == "/") and "/" or ""
    local last = (fullname:sub(-1, -1) == "/") and "/" or ""
    local t = {}
    for m in fullname:gmatch("([^/\\]+)[/\\]?") do
        if m == ".." and next(t) then
            table.remove(t, #t)
        elseif m ~= "." then
            table.insert(t, m)
        end
    end
    return first .. table.concat(t, "/") .. last
end

local function pattern_copy(t, s)
    local r = {ignore=t.ignore, idx=t.idx}
    for i = s, #t do
        r[i-s+1] = t[i]
    end
    return r
end

local function compile(pattern)
    return ("^%s$"):format(pattern
        :gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0")
        :gsub("%*", '[^'..PathSeq..']*')
    )
end

local function pattern_preprocess(root, pattern)
    local path = tostring(pattern)
    local ignore
    if path:match "^!" then
        ignore = true
        path = path:sub(2)
    end
    path = normalize(root, path)
    return path, ignore
end

local function pattern_compile(path, ignore, idx)
    local pattern = {ignore=ignore, idx=idx}
    path:gsub('[^'..PathSeq..']+', function (w)
        if w == '..' and #pattern ~= 0 and pattern[#pattern] ~= '..' then
            if pattern[#pattern] == GlobStar then
                error "`**/..` is not a valid glob."
            end
            pattern[#pattern] = nil
        elseif w ~= '.' then
            if w == "**" then
                pattern[#pattern+1] = GlobStar
            else
                pattern[#pattern+1] = w
            end
        end
    end)
    return pattern
end

local function pattern_sub(res, pattern)
    if pattern[1] == GlobStar then
        res[#res+1] = pattern_copy(pattern, 1)
        res[#res+1] = pattern_copy(pattern, 2)
    else
        res[#res+1] = pattern_copy(pattern, 2)
        if pattern[2] == GlobStar then
            res[#res+1] = pattern_copy(pattern, 3)
        end
    end
end

local function pattern_match_(pats, path)
    if #pats == 0 then
        return MATCH_FAILED
    end
    local pat = pats[1]
    if pat == GlobStar or path:match(pat) then
        return #pats == 1 and MATCH_SUCCESS or MATCH_PENDING
    end
    return MATCH_FAILED
end

local function pattern_match(pattern, path)
    local res = pattern_match_(pattern, path)
    if pattern.ignore then
        if res == MATCH_SUCCESS then
            return MATCH_FAILED
        elseif res == MATCH_FAILED then
            return MATCH_SKIP
        end
        return MATCH_PENDING
    else
        if res == MATCH_SUCCESS then
            return MATCH_SUCCESS
        elseif res == MATCH_FAILED then
            return MATCH_SKIP
        end
        return MATCH_PENDING
    end
end

local function match_prefix(t, s)
    for _, v in ipairs(t) do
        if v[1] ~= s or #v <= 1 then
            return false
        end
    end
    return true
end

local function glob_compile(results, root, patterns, attributes)
    local compiled = {}
    for i, pattern in ipairs(patterns) do
        local path, ignore = pattern_preprocess(root, pattern)
        if ignore or path:match "%*" then
            compiled[#compiled+1] = pattern_compile(path, ignore, i)
        else
            table.insert(results.files, path)
            table.insert(results.attributes, attributes[i])
        end
    end
    if #compiled == 0 then
        return root, compiled
    end
    local gcd = {}
    local first = compiled[1]
    while true do
        local r = first[1]
        if r == nil then
            break
        end
        if r == GlobStar then
            break
        end
        if r:match "%*" then
            break
        end
        if not match_prefix(compiled, r) then
            break
        end
        for _, v in ipairs(compiled) do
            table.remove(v, 1)
        end
        gcd[#gcd+1] = r
    end
    for _, v in ipairs(compiled) do
        for i, w in ipairs(v) do
            if w ~= GlobStar then
                v[i] = compile(w)
            end
        end
    end
    for i = 1, #compiled do
        local v = compiled[i]
        if v[1] == GlobStar and #v > 1 then
            compiled[#compiled+1] = pattern_copy(v, 2)
        end
    end
    if root:sub(1,1) == '/' then
        gcd[1] = '/'.. (gcd[1] or '')
    end
    return normalize(table.unpack(gcd)), compiled
end

local function glob_match_dir(patterns, path)
    local sub = {}
    for _, pattern in ipairs(patterns) do
        local res = pattern_match(pattern, path)
        if res == MATCH_SUCCESS then
        elseif res == MATCH_FAILED then
            return MATCH_FAILED
        elseif res == MATCH_PENDING then
            pattern_sub(sub, pattern)
        end
    end
    if #sub == 0 then
        return MATCH_FAILED
    end
    return MATCH_PENDING, sub
end

local function glob_match_file(patterns, path)
    local idx
    for _, pattern in ipairs(patterns) do
        local res = pattern_match(pattern, path)
        if res == MATCH_SUCCESS then
            if not idx then
                idx = pattern.idx
            end
        elseif res == MATCH_FAILED then
            return MATCH_FAILED
        end
    end
    if idx then
        return MATCH_SUCCESS, idx
    end
    return MATCH_FAILED
end

local function glob_match(patterns, path, status)
    local filename = path:filename():string()
    if status:is_directory() then
        return glob_match_dir(patterns, filename)
    else
        return glob_match_file(patterns, filename)
    end
end

local function glob_scan(results, dir, patterns, attributes)
    if #patterns == 0 then
        return
    end
    for path, status in fs.pairs(fs.path(dir)) do
        local res, sub = glob_match(patterns, path, status)
        if res == MATCH_PENDING then
            glob_scan(results, path, sub, attributes)
        elseif res == MATCH_SUCCESS then
            table.insert(results.files, path:string())
            table.insert(results.attributes, attributes[sub])
        end
    end
end

return function (dir, patterns, attributes)
    local results = {
        files = {},
        attributes = {},
    }
    local root, compiled = glob_compile(results, dir, patterns, attributes)
    glob_scan(results, root, compiled, attributes)
    return results
end
