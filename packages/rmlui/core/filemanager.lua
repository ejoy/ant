local fs = require "filesystem"

local lfont = require "font"
local ltask = require "ltask"
local constructor = require "core.DOM.constructor"

local ServiceResource = ltask.uniqueservice "ant.compile_resource|resource"

local m = {}

local directorys  = { fs.path "/" }

local function import_font(path)
    for p in fs.pairs(path) do
        if fs.is_directory(p) then
            import_font(p)
        elseif fs.is_regular_file(p) then
            if p:equal_extension "otf" or p:equal_extension "ttf" or p:equal_extension "ttc" then
                lfont.import(p:string())
            end
        end
    end
end

function m.font_dir(dir)
    import_font(fs.path(dir))
end

function m.preload_dir(dir)
    directorys[#directorys+1] = fs.path(dir)
end

function m.vfspath(path)
    for i = #directorys, 1, -1 do
        local file = directorys[i] / path
        if fs.exists(file) then
            if file:equal_extension "texture" or file:equal_extension "png" then
                return
            end
            return file:string()
        end
    end
end


function m.realpath(path)
    local _ <close> = fs.switch_sync()
    for i = #directorys, 1, -1 do
        local file = directorys[i] / path
        if fs.exists(file) then
            return file:localpath():string()
        end
    end
end


local function find_texture(path)
    path = fs.path(path)
    if not path:equal_extension "texture" and not path:equal_extension "png" then
        return
    end
    local _ <close> = fs.switch_sync()
    for i = #directorys, 1, -1 do
        local file = directorys[i] / path
        if fs.exists(file) then
            return file:string()
        end
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
    for i = #directorys, 1, -1 do
        local file = directorys[i] / path
        if fs.exists(file) then
            return true
        end
    end
end

return m
