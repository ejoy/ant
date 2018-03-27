local require = import and import(...) or require

local rawtable = require "rawtable"
local util = require "util"
local path = require "filesystem.path"
local seri = require "filesystem.serialize"

return function(filename)
    local asset = require "asset"

    local material = assert(rawtable(filename))

    local material_info = {}
    for k, v in pairs(material) do
        local t = type(v)
        if t == "string" then
            material_info[k] = asset.load(v)
        elseif t == "table" then
            local mempath = string.format("mem://%s.%s", path.remove_ext(filename), k)
            seri.save(mempath, v)
            material_info[k] = asset.load(mempath)
        end
    end

    return material_info
end