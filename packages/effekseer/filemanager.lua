local fs = require "filesystem"
local platform = require "platform"
local bgfx = require "bgfx"
local cr = import_package "ant.compile_resource"

local m = {}

local directorys  = {}

function m.add(dir)
    directorys[#directorys+1] = fs.path(dir)
end

function m.realpath(path)
    local _ <close> = fs.switch_sync()
    local ok, res = pcall(function()
        return cr.compile(path .. "|main.bin"):string()
    end)
    if ok then
        return res
    else
        print("get path error: ", path)
    end
end

return m