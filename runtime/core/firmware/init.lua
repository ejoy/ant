local function split(str)
    local r = {}
    str:gsub('[^/\\]*', function (w) r[#r+1] = w end)
    return r
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
local function get_repopath()
    assert(type(arg[0]) == 'string')
    local t = normalize(arg[0])
    assert(#t > 2)
    t[#t] = nil
    t[#t] = nil
    return table.concat(t, "/")
end

local repopath = get_repopath()
local fs = require "lfs"
local firmware = repopath .. "/firmware"
local boot = assert(loadfile(firmware .. "/bootstrap.lua"))
local vfs = boot(firmware, "127.0.0.1", 2018)
package.loaded.vfs = vfs
vfs.open(repopath)

local function loadfile(path)
    local realpath = vfs.realpath(path)
    if not realpath then
        return nil, ('%s:No such file or directory'):format(path)
    end
    local f, err = io.open(realpath, 'rb')
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@vfs://' .. path)
end

assert(loadfile("main.lua"))()
