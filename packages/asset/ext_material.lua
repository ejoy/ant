local ecs = ...

local bgfx = require "bgfx"
local fs = require "filesystem"
local assetmgr = require "asset"

local utilitypkg = import_package "ant.utility"
local fs_local = utilitypkg.fs_local

local mt = ecs.transform "material_transform"
local function load_state(filename)
	return type(filename) == "string" and fs_local.datalist(fs.path(filename):localpath()) or filename
end

function mt.process_prefab(e)
	local m = e.material
	if m then
		local c = e._cache
		local fx = assetmgr.load_fx(m.fx, c.material_setting)
		local properties = m.properties
		if not properties and #fx.uniforms > 0 then
			properties = {}
		end
	
		c.fx			= fx
		c.properties	= properties
		c.state         = bgfx.make_state(load_state(m.state))
	end
end
