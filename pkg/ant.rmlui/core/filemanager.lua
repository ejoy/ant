local ltask = require "ltask"
local fastio = require "fastio"
local vfs = require "vfs"
local constructor = require "core.DOM.constructor"
local aio = import_package "ant.io"

local ServiceResource = ltask.queryservice "ant.resource_manager|resource"
local m = {}

function m.readfile(source_path)
    return aio.readall(source_path)
end

function m.loadstring(content, source_path, source_line, env)
    if not __ANT_RUNTIME__ then
        local mem, symbol = vfs.read(source_path)
        fastio.free(mem)
        source_path = symbol
    end
    local source = "--@"..source_path..":"..source_line.."\n "..content
    return load(source, source, "t", env)
end

function m.loadfile(source_path, env)
    local mem, symbol = vfs.read(source_path)
    return fastio.loadlua(mem, symbol, env)
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
