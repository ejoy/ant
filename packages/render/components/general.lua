local ecs = ...

local fs = require "filesystem"

local component_util = require "components.util"
local asset = import_package "ant.asset"
local math = import_package "ant.math"

ecs.component "position" (math.util.create_component_vector())
ecs.component "rotation" (math.util.create_component_vector())
ecs.component "scale" (math.util.create_component_vector())

ecs.component_struct "relative_srt" {
	s = math.util.create_component_vector(),
	r = math.util.create_component_vector(),
	t = math.util.create_component_vector(),
}

ecs.tag "editor"

ecs.component_struct "frustum" {
	type = "mat",
	n = 0.1,
	f = 10000,
	l = -1,
	r = 1,
	t = 1,
	b = -1,
	ortho = false,
}

ecs.component "viewid" {
	default = 0,
}

ecs.component_struct "mesh" {
	ref_path = {
		type = "userdata",
		default = "",
		save = function (v, arg)
			assert(type(v) == "table")
			-- local world = arg.world
			-- local e = assert(world[arg.eid])
			-- local comp = assert(e[arg.comp])
			-- assert(comp.assetinfo)
			local pkgname = v[1]
			local respath = v[2]
			return {pkgname:string(), respath:string()}
		end,

		load = function (v, arg)
			assert(type(v) == "string")
			local pkgname = fs.path(v[1])
			local respath = fs.path(v[2])

			local empty = fs.path ""

			if pkgname ~= empty and respath ~= empty then
				local world = arg.world
				local e = assert(world[arg.eid])
				local comp = assert(e[arg.comp])
	
				assert(comp.assetinfo == nil)
				comp.assetinfo = asset.load(pkgname, respath)
			end		
			return v
		end
	}
}

ecs.component_struct "material" {
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
				local refpath = assert(e.path)				
				assert(e.materialinfo)

				local pkgname, respath = refpath[1], refpath[2]
				local assetcontent = asset.load(pkgname, respath)
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
					table.insert(t, {path=refpath, properties=properties})
				end			
			end
			return t
		end,
		load = function (v, arg)
			assert(type(v) == "table")
			local content = {}

			for _, e in ipairs(v) do
				local m = {}
				local refpath = e.path
				local pkgname, respath = refpath[1], fs.path(refpath[2])
				component_util.add_material(content, pkgname, respath)				
			end

			return content
		end
	}
}

ecs.component "can_render" {	
	default = true,
}

ecs.component "can_cast" {
	default = false,
}

ecs.component "name" {	
    type = "string",
}

ecs.tag "can_select"

ecs.component "control_state" {
	type = "string",	
}

ecs.component_struct "parent" {
	eid = -1
}
-- mode = color or factor, gradient, skybox etc
--           
-- mode = 1  color mode use skycolor as classic ambient
-- mode = 0  factor mode use ratio factor of mainlight color
--           ratio factor ，use mainlight's factor directioncolor *factor 
-- mode = 2  gradient ，interpolate with skycolor，midcolor，groundcolor 

ecs.component "ambient_light" { 
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
}

