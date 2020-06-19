local ecs = ...
local world = ecs.world

local assetmgr = require "asset"
local bgfx = require "bgfx"
local mt = ecs.transform "material_transform"
local fs_local = import_package "ant.utility".fs_local
local fs = require "filesystem"
local function load_state(filename)
	return type(filename) == "string" and fs_local.datalist(fs.path(filename):localpath()) or filename
end

local function load_material(m, setting)
	local fx = assetmgr.load_fx(m.fx, setting)
	local properties = m.properties
	if not properties and #fx.uniforms > 0 then
		properties = {}
	end

	return {
		fx = fx,
		properties = properties,
		state = bgfx.make_state(load_state(m.state))
	}
end

function mt.process_prefab(e)
	local m = e.material
	if m then
		local c = e._cache
		local m = load_material(m, c.material_setting)
		c.fx, c.properties, c.state = m.fx, m.properties, m.state
	end
end

local im = ecs.interface "imaterial"
function im.load(materialpath, setting)
	local m = world.component "resource"(materialpath)
	return load_material(m, setting)
end

function im.set_property(eid, who, what)
	local rp = world:interface "ant.render|render_properties".data()
	if rp[who] then
		error(("should not update golbal uniform from imaterial:set_property: %s"):format(who))
	end
	local rc = world[eid]._rendercache
	rc.properties[who].value = what
end
