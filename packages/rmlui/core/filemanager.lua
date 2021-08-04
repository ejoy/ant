local fs = require "filesystem"

local cr = import_package "ant.compile_resource"
local hwi = import_package "ant.hwi"
local lfont = require "font"

hwi.update_identity()

local m = {}

local directorys  = {}

local function import_font(path)
    for p in path:list_directory() do
        if fs.is_directory(p) then
            import_font(p)
        elseif fs.is_regular_file(p) then
            if p:equal_extension "otf" or p:equal_extension "ttf" or p:equal_extension "ttc" then
                lfont.import(p:string())
            end
        end
    end
end

local function compile_texture(path)
    return cr.compile(path:string() .. "|main.bin"):string()
end

function m.preload_dir(dir)
    dir = fs.path(dir)
    directorys[#directorys+1] = dir
    import_font(dir)
end

function m.realpath(path)
    for i = #directorys, 1, -1 do
        local file = directorys[i] / path
        if fs.exists(file) then
            if file:equal_extension "texture" or file:equal_extension "png" then
                return compile_texture(file)
            end
            return file:localpath():string()
        end
    end
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
