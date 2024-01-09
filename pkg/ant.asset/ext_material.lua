local serialize = import_package "ant.serialize"
local bgfx      = require "bgfx"
local async 	= require "async"
local aio       = import_package "ant.io"
local matpkg	= import_package "ant.material"
local MA 		= matpkg.arena

local function load(filename)
    return type(filename) == "string" and serialize.parse(filename, aio.readall(filename)) or filename
end

local function loader(filename)
    local material, attribute = async.material_create(filename)

    if material.state then
		material.state = bgfx.make_state(load(material.state))
    end

    if material.stencil then
        material.stencil = bgfx.make_stencil(load(material.stencil))
    end

	if material.fx.prog then
		material.attribs, material.systems = attribute.attribs, attribute.systems
    	material.object = MA.material_load(filename, material.state, material.stencil, material.fx.prog, material.systems, material.attribs)
	end
	if material.fx.depth then
		local ad = attribute.depth
		material.depth = {
			attribs = ad.attribs,
			systems = ad.systems,
			object = MA.material_load(filename .. "|depth", material.state, material.stencil, material.fx.depth.prog, ad.attribs, ad.systems)
		}
	end
	if material.fx.di then
		local ad = attribute
		material.di = {
			attribs = ad.attribs,
			systems = ad.systems,
			object = MA.material_load(filename .. "|di", material.state, material.stencil, material.fx.di.prog, ad.systems, ad.attribs)
		}
	end
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
