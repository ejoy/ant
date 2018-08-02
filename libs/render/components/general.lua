local ecs = ...

local component_util = require "render.components.util"
local asset = require "asset"

ecs.component "position"{
    v = {type="vector"}
}

ecs.component "rotation"{
    v = {type="vector"}
}

ecs.component "scale" {
    v = {type="vector"}
}

ecs.component "frustum" {
    isortho = false,
    n = 0.1,
    f = 10000,
    l = -1,
    r = 1,
    t = 1,
    b = -1,
}

ecs.component "viewid" {
    id = 0
}

ecs.component "mesh" {
	path = {
		type = "userdata",
		default = "",
		save = function (v, arg)
			assert(type(v) == "string")
			-- local world = arg.world
			-- local e = assert(world[arg.eid])
			-- local comp = assert(e[arg.comp])
			-- assert(comp.assetinfo)
			return v
		end,

		load = function (v, arg)
			assert(type(v) == "string")
			local world = arg.world
			local e = assert(world[arg.eid])
			local comp = assert(e[arg.comp])

			if v ~= "" then
				assert(comp.assetinfo == nil)
				comp.assetinfo = asset.load(v)
			else
				dddddd = 0
			end
			return v
		end
	}
}

ecs.component "material" {
	content = {
		type = "userdata",
		defatult = {
			{
				path = "",
				properties = {}
			}
		},
		save = function (v, arg)
			local t = {}
			for _, e in ipairs(v) do				
				local pp = assert(e.path)
				assert(pp ~= "")
				assert(e.materialinfo)

				local assetcontent = asset.load(pp)
				local src_properties = assetcontent.properties		
				if src_properties then
					local properties = {}
					for k, v in pairs(src_properties) do
						local p = e.properties[k]
						local type = p.type
						if type == "texture" then
							properties[k] = {name=p.name, type=type, path=v.default, stage=p.stage}
						else
							properties[k] = p
						end
					end
				end
				table.insert(t, {path=pp, properties=properties})
			
			end
			return t
		end,
		load = function (v, arg)
			assert(type(v) == "table")
			local content = {}
			
			for _, e in ipairs(v) do
				local pp = e.path
				local materialinfo = asset.load(pp)
				local properties = nil
				if e.properties then
					properties = {}
					component_util.update_properties(properties, e.properties)
				end
				table.insert(content, {path=pp, materialinfo=materialinfo, properties=properties})
			end

			return content
		end
	}
}

ecs.component "can_render" {
	visible = true
}

ecs.component "name" {
    n = ""
}

ecs.component "can_select" {

}

ecs.component "last_render"{
    enable = true
}

ecs.component "control_state" {
    state = "camera"
}

ecs.component "hierarchy_parent" {
	eid = -1
}
-- mode = color or factor, gradient, skybox etc
--           
-- mode = 1  color mode use skycolor as classic ambient
-- mode = 0  factor mode use ratio factor of mainlight color
--           ratio factor ，use mainlight's factor directioncolor *factor 
-- mode = 2  gradient ，interpolate with skycolor，midcolor，groundcolor 

ecs.component "ambient_light" { 
	data  = {
		type = "userdata",
		default = {
			mode   = "color",
			factor = 0.3,     			    
			skycolor = {1,1,1,1},
			midcolor = {1,1,1,1},
			groundcolor = {1,1,1,1},
			-- gradient = {          -- 这种模式，过于复杂多层，简化到上层，平面化
			-- 	skycolor = {1,1,1,1},
			-- 	midcolor = {1,1,1,1},
			-- 	groundcolor = {1,1,1,1},
			-- },
		},
	},
}
