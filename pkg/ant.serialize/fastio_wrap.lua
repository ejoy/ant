local fastio = require "fastio"
local vfs = require "vfs"
local ltask = require "ltask"

local ServiceResource
local function compile(path)
    if not ServiceResource then
        ServiceResource = ltask.uniqueservice "ant.resource_manager|resource"
    end
	return ltask.call(ServiceResource, "compile", path)
end

local m = {}

function m.readall(path)
    local realpath = assert(vfs.realpath(path), path)
    return fastio.readall(realpath, path)
end

function m.readall_s(path)
    local realpath = assert(vfs.realpath(path), path)
    return fastio.readall_s(realpath, path)
end

function m.readall_compiled(path)
    local realpath = assert(compile(path), path)
    return fastio.readall(realpath, path)
end

function m.readall_compiled_s(path)
    local realpath = assert(compile(path), path)
    return fastio.readall_s(realpath, path)
end

return m
