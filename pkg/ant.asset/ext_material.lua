local serialize = import_package "ant.serialize"
local bgfx      = require "bgfx"
local async 	= require "async"
local fastio 	= serialize.fastio

local setting   = import_package "ant.settings"
local use_cluster_shading<const>	= setting:get "graphic/cluster_shading" ~= 0
local cs_skinning<const>			= setting:get "graphic/skinning/use_cs"

local matpkg	= import_package "ant.material"
local MA 		= matpkg.arena

local function load(filename)
    return type(filename) == "string" and serialize.parse(filename, fastio.readall(filename)) or filename
end

local function loader(filename)
    local material, attribute = async.material_create(filename)

    if material.state then
		material.state = bgfx.make_state(load(material.state))
    end

    if material.stencil then
        material.stencil = bgfx.make_stencil(load(material.stencil))
    end
    material.attrib, material.system = attribute.attrib, attribute.system
    material.object = MA.material_load(filename, material.state, material.stencil, material.fx.prog, material.system, material.attrib)
    return material
end

local function unloader(m)
	m.object:release()
	m.object = nil

	local function destroy_handle(fx, n)
		local h = fx[n]
		if h then
			bgfx.destroy(h)
			fx[n] = nil
		end
	end
	
	-- local fx = m.fx
	-- assert(fx.prog)
	-- destroy_handle(fx, "prog")

	-- destroy_handle(fx, "vs")
	-- destroy_handle(fx, "fs")
	-- destroy_handle(fx, "cs")
end

return {
    loader = loader,
    unloader = unloader,
}
