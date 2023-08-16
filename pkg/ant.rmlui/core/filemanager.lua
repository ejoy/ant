local fs = require "filesystem"
local ltask = require "ltask"
local constructor = require "core.DOM.constructor"

local ServiceResource = ltask.queryservice "ant.compile_resource|resource"

local m = {}

local rt_table = {}

local prefixPath = fs.path "/"

function m.set_prefix(v)
    prefixPath = fs.path(v)
end

function m.fullpath(source_path)
    return (prefixPath / source_path):string()
end

function m.realpath(source_path)
    local _ <close> = fs.switch_sync()
    return (prefixPath / source_path):localpath():string()
end

function m.exists(path)
    local _ <close> = fs.switch_sync()
    return fs.exists(prefixPath / path)
end

function m.readfile(source_path)
    local realpath = m.realpath(source_path)
    local f = io.open(realpath)
    if not f then
        return nil, ('%s:No such file or directory.'):format(m.fullpath(source_path))
    end
    local data = f:read 'a'
    f:close()
    return data
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
        elseif rt_table[path] and (rt_table[path].w ~= width or rt_table[path].h ~= height) then
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
            local info = ltask.call(ServiceResource, "texture_create", m.fullpath(path))
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

function m.loadString(content, source_path, source_line, env)
    local realpath = m.realpath(source_path)
    local source = "--@"..realpath..":"..source_line.."\n "..content
    return load(source, source, "t", env)
end

function m.loadFile(source_path, env)
    local realpath = m.realpath(source_path)
    local f = io.open(realpath)
    if not f then
        return nil, ('%s:No such file or directory.'):format(m.fullpath(source_path))
    end
    local str = f:read 'a'
    f:close()
    return load(str, "@" .. realpath, "bt", env)
end

return m
