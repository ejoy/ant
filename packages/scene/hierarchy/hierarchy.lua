local ecs = ...
local world = ecs.world
local assetmgr = import_package "ant.asset"
local fs = require "filesystem"

local h = ecs.component_struct "hierarchy" {
	ref_path = {
		type = "userdata",
		default = "",
		save = function(v, arg)
			assert(type(v) == "table")
			local e = world[arg.eid]
			local comp = e[arg.comp]	
			local builddata = comp.builddata
			assert(builddata)
			local pkgname, respath = v[1], v[2]
			return {pkgname, respath:string()}
		end,
		load = function(v)
			assert(type(v) == "table")			
			local pkgname, respath = fs.path(v[1]), fs.path(v[2])
			assert(fs.path(v):extension() == fs.path ".hierarchy")
			local e = world[arg.eid]
			local comp = e[arg.comp]

			comp.builddata = assert(assetmgr.load(pkgname, respath))
			return v
		end
	},
}

function h:init()
	self.builddata = nil
end

ecs.component "hierarchy_name_mapper"{    
	type = "userdata", 
	save = function(v, arg)
		assert(type(v) == "table")
		local t = {}
		for k, eid in pairs(v) do
			assert(type(eid) == "number")
			local e = world[eid]
			local seri = e.serialize
			if seri then
				t[k] = seri.uuid
			end
		end
		return t
	end,
	load = function(v, arg)
		assert(type(v) == "table")
		return v
	end
}