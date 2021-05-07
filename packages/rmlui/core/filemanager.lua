local fs = require "filesystem"
local platform = require "platform"
local bgfx = require "bgfx"
local cr = import_package "ant.compile_resource"

local os = platform.OS
do
    local hwcaps = bgfx.get_caps()
    local renderer = hwcaps.rendererType

    local ss = os.."_"..renderer
    ss = ss .. "_" .. "hd" .. (hwcaps.homogeneousDepth and "1" or "0")
    ss = ss .. "_" .. "obl" .. (hwcaps.originBottomLeft and "1" or "0")
    cr.set_identity(ss:lower())
end

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
