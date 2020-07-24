local utility = require 'remotedebug.utility'
local ev = require 'backend.event'
local rdebug = require 'remotedebug.visitor'
local absolute = utility.fs_absolute
local u2a = utility.u2a or function (...) return ... end
local a2u = utility.a2u or function (...) return ... end

local isWindows = package.config:sub(1,1) == "\\"
local sourceFormat = isWindows and "path" or "linuxpath"
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
        return u2a(s)
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
    local visitor = rdebug.field(rdebug.field(rdebug._G, "package"), name)
    if not rdebug.assign(visitor, value) then
        return
    end
end

ev.on('initializing', function(config)
    sourceFormat = config.sourceFormat or (isWindows and "path" or "linuxpath")
    pathFormat = config.pathFormat or "path"
    useWSL = config.useWSL
    useUtf8 = config.sourceCoding == "utf8"
    init_searchpath(config, 'path')
    init_searchpath(config, 'cpath')
end)

local function normalize_posix(p)
    local stack = {}
    p:gsub('[^/]*', function (w)
        if #w == 0 and #stack ~= 0 then
        elseif w == '..' and #stack ~= 0 and stack[#stack] ~= '..' then
            stack[#stack] = nil
        elseif w ~= '.' then
            stack[#stack + 1] = w
        end
    end)
    return stack
end

local function normalize_win32(p)
    local stack = {}
    p:gsub('[^/\\]*', function (w)
        if #w == 0 and #stack ~= 0 then
        elseif w == '..' and #stack ~= 0 and stack[#stack] ~= '..' then
            stack[#stack] = nil
        elseif w ~= '.' then
            stack[#stack + 1] = w
        end
    end)
    return stack
end

local m = {}

function m.fromwsl(s)
    if sourceFormat == "string" then
        return s
    end
    if not useWSL or not s:match "^/mnt/%a" then
        return s
    end
    return s:gsub("^/mnt/(%a)", "%1:")
end

function m.source_native(s)
    return sourceFormat == "path" and s:lower() or s
end

function m.path_native(s)
    return pathFormat == "path" and s:lower() or s
end

function m.source_normalize(path)
    if sourceFormat == "string" then
        return path
    end
    if sourceFormat == "path" then
        local absolute_path = isWindows and absolute(path) or path
        return table.concat(normalize_win32(absolute_path), '/')
    end
    local absolute_path = isWindows and path or absolute(path)
    return table.concat(normalize_posix(absolute_path), '/')
end

function m.path_normalize(path)
    local normalize = pathFormat == "path" and normalize_win32 or normalize_posix
    return table.concat(normalize(path), '/')
end

function m.path_relative(path, base)
    local normalize = pathFormat == "path" and normalize_win32 or normalize_posix
    local equal = pathFormat == "path"
        and (function(a, b) return a:lower() == b:lower() end)
        or (function(a, b) return a == b end)
    local rpath = normalize(path)
    local rbase = normalize(base)
    while #rpath > 0 and #rbase > 0 and equal(rpath[1], rbase[1]) do
        table.remove(rpath, 1)
        table.remove(rbase, 1)
    end
    if #rpath == 0 and #rbase== 0 then
        return "./"
    end
    local s = {}
    for _ in ipairs(rbase) do
        s[#s+1] = '..'
    end
    for _, e in ipairs(rpath) do
        s[#s+1] = e
    end
    return table.concat(s, '/')
end

function m.path_filename(path)
    local normalize = pathFormat == "path" and normalize_win32 or normalize_posix
    local paths = normalize(path)
    return paths[#paths]
end

m.a2u = a2u

return m
