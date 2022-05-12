local ecs	= ...
local world = ecs.world
local w		= world.w

local url = import_package "ant.url"

local assetmgr		= require "asset"
local sa			= require "system_attribs"

local imaterial = ecs.interface "imaterial"

function imaterial.set_property(e, who, what)
	e.render_object.material[who] = what
end

function imaterial.get_property(e, who)
	return e.render_object.material[who]
end

function imaterial.load(mp, setting)
	local material = assetmgr.resource(url.create(mp, setting))
	return {
		material= material.object:instance(),
		fx		= material.fx
	}
end

function imaterial.load_url(u)
	return assetmgr.resource(u)
end

function imaterial.system_attribs()
	return sa
end

local ms = ecs.system "material_system"

function ms:component_init()
	w:clear "material_result"
	for e in w:select "INIT material:in material_setting?in material_result:new" do
		e.material_result = assetmgr.resource(url.create(e.material, e.material_setting))
	end
end