local cr        = import_package "ant.compile_resource"
local datalist  = require "datalist"
local assetmgr  = require "asset"
local bgfx      = require "bgfx"

local function load_elem(filename)
    return type(filename) == "string" and datalist.parse(cr.read_file(filename)) or filename
end

local function init(material)
    if type(material.fx) == "string" then
        material.fx = assetmgr.resource(material.fx)
    end
    material.state = bgfx.make_state(load_elem(material.state))
    material.setting = material.setting and load_elem(material.setting) or nil
    if material.properties then
        for _, v in pairs(material.properties) do
            if v.stage then
                v.texture = assetmgr.resource(v.texture)
            end
        end
    end
    return material
end

local function loader(filename)
    local m = datalist.parse(cr.read_file(filename))
    return init(m)
end

local function unloader()
end

return {
    init = init,
    loader = loader,
    unloader = unloader,
}
