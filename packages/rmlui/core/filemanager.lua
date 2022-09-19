local fs = require "filesystem"
local ltask = require "ltask"
local textureman = require "textureman.client"
local constructor = require "core.DOM.constructor"
local bundle = import_package "ant.bundle"

local ServiceResource = ltask.queryservice "ant.compile_resource|resource"
local DefaultTexture = ltask.call(ServiceResource, "texture_default")

local m = {}

local prefixPath = fs.path "/"

local function fullpath(path)
    return (prefixPath / path):string()
end

function m.add_bundle(path)
    bundle.open(path)
end

function m.del_bundle(path)
    bundle.close(path)
end

function m.set_prefix(v)
    prefixPath = fs.path(v)
end

function m.realpath(source_path)
    return bundle.get(fullpath(source_path))
end

local pendQueue = {}
local eventQueue = {}
local readyQueue = {}

function m.loadTexture(doc, e, path)
    local realpath = fullpath(path)
    local element = constructor.Element(doc, false, e)
    local q = pendQueue[path]
    if q then
        q[#q+1] = element
        return
    end
    pendQueue[path] = {element}
    ltask.fork(function ()
        local info = ltask.call(ServiceResource, "texture_create", realpath)
        local handle = textureman.texture_get(info.id)
        if handle == DefaultTexture then
            eventQueue[info.id] = {path, info}
        else
            readyQueue[#readyQueue+1] = {
                path = path,
                elements = pendQueue[path],
                handle = handle,
                width = info.texinfo.width,
                height = info.texinfo.height,
            }
            pendQueue[path] = nil
        end
    end)
end

function m.updateTexture()
    while true do
        local id = textureman.event_pop()
        if not id then
            break
        end
        local e = eventQueue[id]
        if e then
            local path, info = e[1], e[2]
            readyQueue[#readyQueue+1] = {
                path = path,
                elements = pendQueue[path],
                handle = textureman.texture_get(info.id),
                width = info.texinfo.width,
                height = info.texinfo.height,
            }
            pendQueue[path] = nil
            eventQueue[id] = nil
        end
    end
    if #readyQueue == 0 then
        return
    end
    local q = readyQueue
    readyQueue = {}
    return q
end

function m.exists(path)
    return bundle.exist(fullpath(path))
end

function m.loadString(content, source_path, source_line, env)
    local path = fullpath(source_path)
	local source = "--@"..path..":"..source_line.."\n "..content
    return load(source, source, "t", env)
end

function m.loadFile(source_path, env)
    local path = fullpath(source_path)
    local realpath = bundle.get(path)
    local f = io.open(realpath)
    if not f then
        return nil, ('%s:No such file or directory.'):format(path)
    end
    local str = f:read 'a'
    f:close()
    return load(str, "@" .. path, "bt", env)
end

return m
