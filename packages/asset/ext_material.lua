local cr = import_package "ant.compile_resource"
local datalist = require "datalist"
local assetmgr = require "asset"
local bgfx = require "bgfx"

local function load_state(filename)
	return type(filename) == "string" and datalist.parse(cr.read_file(filename)) or filename
end

local function init(world, material)
    if type(material.fx) == "string" then
        material.fx = assetmgr.resource(world, material.fx)
    end
    material.state = bgfx.make_state(load_state(material.state))
    if material.properties then
        for _, v in pairs(material.properties) do
            if v.stage then
                v.texture = assetmgr.resource(world, v.texture)
            end
        end
    end
    return material
end

local function loader(filename, world)
    local m = datalist.parse(cr.read_file(filename))
    return init(world, m)
end

local function unloader()
end

return {
    init = init,
    loader = loader,
    unloader = unloader,
}
