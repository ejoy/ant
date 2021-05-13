local fs = require "filesystem"

local cr = import_package "ant.compile_resource"
local hwi = import_package "ant.hwi"

hwi.update_identity()

local m = {}

local directorys  = {}

function m.add(dir)
    directorys[#directorys+1] = fs.path(dir)
end

local function compile_texture(path)
    return cr.compile(path:string() .. "|main.bin"):string()
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

return m
