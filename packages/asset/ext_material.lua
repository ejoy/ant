local cr        = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"
local assetmgr  = require "asset"
local bgfx      = require "bgfx"

local function load(filename)
    return type(filename) == "string" and serialize.parse(filename, cr.read_file(filename)) or filename
end

local function init(material)
    if (type(material.fx.setting) == "string") then
        material.fx.setting = material.fx.setting and load(material.fx.setting) or nil
    end
    if material.state then
        material.state = bgfx.make_state(load(material.state))
    end

    if material.stencil then
        material.stencil = bgfx.make_stencil(load(material.stencil))
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
    return init(load(filename))
end

local function unloader()
end

return {
    init = init,
    loader = loader,
    unloader = unloader,
}
