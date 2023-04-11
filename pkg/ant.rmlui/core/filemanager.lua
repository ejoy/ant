local fs = require "filesystem"
local ltask = require "ltask"
local constructor = require "core.DOM.constructor"
local bundle = import_package "ant.bundle"

local ServiceResource = ltask.queryservice "ant.compile_resource|resource"

local m = {}

local rt_table = {}

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
local readyQueue = {}

function m.getTextureTable()
    return ltask.call(ServiceWorld, "get_texture_table") 
end

function m.loadTexture(doc, e, path, width, height, isRT)
    width  = math.floor(width)
    height = math.floor(height)
    local realpath = fullpath(path)
    local element = constructor.Element(doc, false, e)
    local q = pendQueue[path]
    if q then
        q[#q+1] = element
        return
    end
    pendQueue[path] = {element}
    if isRT then
        if not rt_table[path] then
            rt_table[path] = {
                w = width,
                h = height
            }
            ltask.fork(function ()
                local id = ltask.call(ServiceWorld, "render_target_create", width, height, path)
                readyQueue[#readyQueue+1] = {
                    path = path,
                    elements = pendQueue[path],
                    id = id,
                    width = width,
                    height = height,
                }
                pendQueue[path] = nil
            end) 
        elseif rt_table[path] and rt_table[path].w ~= width or rt_table[path].h ~= height then
            ltask.fork(function ()
                local id = ltask.call(ServiceWorld, "render_target_adjust", width, height, path)
                readyQueue[#readyQueue+1] = {
                    path = path,
                    elements = pendQueue[path],
                    id = id,
                    width = width,
                    height = height,
                }
                pendQueue[path] = nil
            end) 
        end 
    else
        ltask.fork(function ()
            local info = ltask.call(ServiceResource, "texture_create", realpath)
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
