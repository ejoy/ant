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
    elseif (type(material.fx.setting) == "string") then
        material.fx.setting = material.fx.setting and load_elem(material.fx.setting) or nil
    end
    if material.state then
        material.state = bgfx.make_state(load_elem(material.state))
    end

    if material.stencil then
        material.stencil = bgfx.make_stencil(load_elem(material.stencil))
    end
    if material.properties then
        for _, v in pairs(material.properties) do
            if v.texture then
                assert(v.stage ~= nil)
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
