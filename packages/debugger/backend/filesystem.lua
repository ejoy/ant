local ok, fs = pcall(require, 'filesystem')
if not ok then fs = nil end

local default_sep = package.config:sub(1, 1)

local function split(str)
    local r = {}
    str:gsub('[^/\\]*', function (w) r[#r+1] = w end)
    return r
end

local function absolute(p)
    if p:find(':', 1, true) then return p end
    if not fs then return p end
    return fs.absolute(fs.path(p)):string()
end

local function normalize(p)
    local stack = {}
    for _, elem in ipairs(split(absolute(p))) do
        if #elem == 0 and #stack ~= 0 then
        elseif elem == '..' and #stack ~= 0 and stack[#stack] ~= '..' then
            stack[#stack] = nil
        elseif elem ~= '.' then
            stack[#stack + 1] = elem
        end
    end
    return stack
end

local function normalize_native(p)
    local stack = {}
    for _, elem in ipairs(split(absolute(p))) do
        if #elem == 0 and #stack ~= 0 then
        elseif elem == '..' and #stack ~= 0 and stack[#stack] ~= '..' then
            stack[#stack] = nil
        elseif elem ~= '.' then
            stack[#stack + 1] = elem:lower()
        end
    end
    return stack
end

local m = {}

function m.normalize(path, sep)
    return table.concat(normalize(path), sep or default_sep)
end

function m.normalize_native(path)
    return table.concat(normalize_native(path), '/')
end

function m.relative(path, base, sep)
    sep = sep or default_sep
    local rpath = normalize(path)
    local rbase = normalize(base)
    while #rpath > 0 and #rbase > 0 and rpath[1] == rbase[1] do
        table.remove(rpath, 1)
        table.remove(rbase, 1)
    end
    if #rpath == 0 and #rbase== 0 then
        return "." .. sep
    end
    local s = {}
    for _ in ipairs(rbase) do
        s[#s+1] = '..'
    end
    for _, e in ipairs(rpath) do
        s[#s+1] = e
    end
    return table.concat(s, sep)
end

function m.filename(path)
    local paths = normalize(path)
    return paths[#paths]
end

return m
