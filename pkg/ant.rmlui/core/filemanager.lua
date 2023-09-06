local ltask = require "ltask"
local fastio = require "fastio"
local vfs = require "vfs"
local constructor = require "core.DOM.constructor"

local ServiceResource = ltask.queryservice "ant.resource_manager|resource"
local ServiceWorld    = ltask.queryservice "ant.window|world"
local m = {}

function m.is_file(path)
    return vfs.type(path) == "file"
end

function m.readfile(source_path)
    local realpath = vfs.realpath(source_path)
    return fastio.readall(realpath, source_path)
end

function m.loadstring(content, source_path, source_line, env)
    local realpath = vfs.realpath(source_path)
    local source = "--@"..realpath..":"..source_line.."\n "..content
    return load(source, source, "t", env)
end

function m.loadfile(source_path, env)
    local realpath = vfs.realpath(source_path)
    return fastio.loadfile(realpath, source_path, env)
end

local pendQueue = {}
local readyQueue = {}

function m.loadTexture(doc, e, path, width, height, isRT)
    width  = math.floor(width)
    height = math.floor(height)
    local element = constructor.Element(doc, false, e)
    local q = pendQueue[path]
    if q then
        q[#q+1] = element
        return
    end
    pendQueue[path] = {element}
    if isRT then
        ltask.fork(function ()
            local id = ltask.call(ServiceWorld, "render_target_update", width, height, path)
            readyQueue[#readyQueue+1] = {
                path = path,
                elements = pendQueue[path],
                id = id,
                width = width,
                height = height,
            }
            pendQueue[path] = nil
        end) 
    else
        ltask.fork(function ()
            local info = ltask.call(ServiceResource, "texture_create", path)
            readyQueue[#readyQueue+1] = {
                path = path,
                elements = pendQueue[path],
                id = info.id,
                width = info.texinfo.width,
                height = info.texinfo.height,
            }
            pendQueue[path] = nil
        end)
    end
end

function m.updateTexture()
    if #readyQueue == 0 then
        return
    end
    local q = readyQueue
    readyQueue = {}
    return q
end

return m
