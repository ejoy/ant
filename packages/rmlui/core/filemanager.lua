local fs = require "filesystem"
local ltask = require "ltask"
local constructor = require "core.DOM.constructor"
local bundle = import_package "ant.bundle"

local ServiceResource = ltask.queryservice "ant.compile_resource|resource"

local m = {}

local prefixPath = fs.path "/"

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
    local path = (prefixPath / source_path):string()
    return bundle.get(path)
end

local function find_texture(path)
    path = fs.path(path)
    if not path:equal_extension "texture" and not path:equal_extension "png" then
        return
    end
    local _ <close> = fs.switch_sync()
    local file = prefixPath / path
    if fs.exists(file) then
        return file:string()
    end
end

local pendQueue = {}
local readyQueue = {}

function m.loadTexture(doc, e, path)
    local realpath = find_texture(path)
    if not realpath then
        readyQueue[#readyQueue+1] = {
            path = path,
        }
        return
    end
    local element = constructor.Element(doc, false, e)
    local q = pendQueue[path]
    if q then
        q[#q+1] = element
        return
    end
    pendQueue[path] = {element}
    ltask.fork(function ()
        local ok, info = pcall(ltask.call, ServiceResource, "texture_create_complete", realpath)
        if ok then
            readyQueue[#readyQueue+1] = {
                path = path,
                elements = pendQueue[path],
                handle = info.handle,
                width = info.texinfo.width,
                height = info.texinfo.height,
            }
        else
            readyQueue[#readyQueue+1] = {
                path = path,
            }
        end
        pendQueue[path] = nil
    end)
end

function m.texture_queue()
    if #readyQueue == 0 then
        return
    end
    local q = readyQueue
    readyQueue = {}
    return q
end

function m.exists(path)
    local file = (prefixPath / path):string()
    return bundle.exist(file)
end

function m.loadString(content, source_path, source_line, env)
    local path = (prefixPath / source_path):string()
	local source = "--@"..path..":"..source_line.."\n "..content
    return load(source, source, "t", env)
end

function m.loadFile(source_path, env)
    local path = (prefixPath / source_path):string()
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
