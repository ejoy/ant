local fs = require 'remotedebug.filesystem'
local ev = require 'common.event'
local rdebug = require 'remotedebug.visitor'

local function prequire(name)
    local ok, res = pcall(require, name)
    if ok then
        return res
    end
end
local unicode = prequire 'remotedebug.unicode'

local default_sep = package.config:sub(1, 1)
local sourceFormat = "path"
local pathFormat = "path"
local useWSL = false
local useUtf8 = false

local function towsl(s)
    if not useWSL or not s:match "^%a:" then
        return s
    end
    return s:gsub("\\", "/"):gsub("^(%a):", function(c)
        return "/mnt/"..c:lower()
    end)
end

local function nativepath(s)
    if not useWSL and not useUtf8 then
        return unicode.u2a(s)
    end
    return towsl(s)
end

local function init_searchpath(config, name)
    if not config[name] then
        return
    end
    local value = config[name]
    if type(value) == 'table' then
        local path = {}
        for _, v in ipairs(value) do
            if type(v) == "string" then
                path[#path+1] = nativepath(v)
            end
        end
        value = table.concat(path, ";")
    else
        value = nativepath(value)
    end
    local visitor = rdebug.index(rdebug.index(rdebug._G, "package"), name)
    if not rdebug.assign(visitor, value) then
        return
    end
end

ev.on('initializing', function(config)
    sourceFormat = config.sourceFormat or "path"
    pathFormat = config.pathFormat or "path"
    useWSL = config.useWSL
    useUtf8 = config.sourceCoding == "utf8"
    init_searchpath(config, 'path')
    init_searchpath(config, 'cpath')
end)

local function split(str)
    local r = {}
    str:gsub('[^/\\]*', function (w) r[#r+1] = w end)
    return r
end

local function fromwsl(s)
    if not useWSL or not s:match "^/mnt/%a" then
        return s
    end
    return s:gsub("^/mnt/(%a)", "%1:")
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

function m.normalize_serverpath(path)
    if sourceFormat == "string" then
        return path
    end
    return fromwsl(m_normalize(absolute(path)))
end

function m.narive_normalize_serverpath(path)
    if sourceFormat == "string" then
        return path
    end
    if sourceFormat == "linuxpath" then
        return m_normalize(absolute(path), '/')
    end
    return m_normalize(absolute(path), '/'):lower()
end

function m.normalize_clientpath(path)
    return m_normalize(path)
end

function m.narive_normalize_clientpath(path)
    if pathFormat == "linuxpath" then
        return m_normalize(path)
    end
    return m_normalize(path):lower()
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

m.unicode = unicode

return m
