local fs = require 'common.filesystem'

local default_sep = package.config:sub(1, 1)

local function split(str)
    local r = {}
    str:gsub('[^/\\]*', function (w) r[#r+1] = w end)
    return r
end

local function absolute(p)
    return fs.absolute(fs.path(p)):string()
end

local function normalize(p)
    local stack = {}
    for _, elem in ipairs(split(p)) do
        if #elem == 0 and #stack ~= 0 then
        elseif elem == '..' and #stack ~= 0 and stack[#stack] ~= '..' then
            stack[#stack] = nil
        elseif elem ~= '.' then
            stack[#stack + 1] = elem
        end
    end
    return stack
end

local m = {}

local function m_normalize(path, sep)
    return table.concat(normalize(path), sep or default_sep)
end

function m.normalize_serverpath(path, sep)
    return m_normalize(absolute(path), sep)
end

function m.normalize_clientpath(path, sep)
    return m_normalize(path, sep)
end

function m.narive_normalize_serverpath(path)
    return m_normalize(absolute(path), '/'):lower()
end

function m.narive_normalize_clientpath(path)
    return m_normalize(path, '/'):lower()
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
