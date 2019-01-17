local ecs = ...

local fs = require "filesystem"

local component_util = require "components.util"
local asset = import_package "ant.asset"
local math = import_package "ant.math"

ecs.component "position" (math.util.create_component_vector())
ecs.component "rotation" (math.util.create_component_vector())
ecs.component "scale" (math.util.create_component_vector())

ecs.component "relative_srt" {
	s = math.util.create_component_vector(),
	r = math.util.create_component_vector(),
	t = math.util.create_component_vector(),
}

ecs.tag "editor"

ecs.component "frustum" {
	type = "mat",
	n = 0.1,
	f = 10000,
	l = -1,
	r = 1,
	t = 1,
	b = -1,
	ortho = false,
}

ecs.component("viewid", 0)

local mesh = ecs.component "mesh" {
}

function mesh:save(arg)
	assert(type(self.ref_path[2]) == "table") -- vfs.path
	local world = arg.world
	local e = assert(world[arg.eid])
	local comp = assert(e[arg.comp])
	assert(comp.assetinfo)
	self.ref_path[2] = self.ref_path[2]:string()
	return self
end

function mesh:load()
	assert(self.assetinfo == nil)
	assert(type(self.ref_path[2]) == "string")
	self.ref_path[2] = fs.path(self.ref_path[2])
	self.assetinfo = asset.load(self.ref_path[1], self.ref_path[2])
	return self
end

local material = ecs.component "material" {
	content = {}
}

function material:save(arg)
	local t = {}
	for _, e in ipairs(self.content) do
		local pp = assert(e.path)
		assert(pp ~= "")
		assert(e.materialinfo)

		local assetcontent = asset.load(pp[1], pp[2])
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
			e.properties = properties
		end	
		e.path[2] = e.path[2]:string()		
	end
	return self
end

function material:load()
	local content = {}
	for _, e in ipairs(self.content) do
		local m = {}
		component_util.add_material(m, e.path[1], e.path[2])
		content[#content+1] = m
	end
	return content
end

ecs.component("can_render", true)

ecs.component("can_cast", false)

ecs.component("name", "")

ecs.tag "can_select"

ecs.component("control_state", "")

ecs.component "parent" {
	eid = -1
}
-- mode = color or factor, gradient, skybox etc
--           
-- mode = 1  color mode use skycolor as classic ambient
-- mode = 0  factor mode use ratio factor of mainlight color
--           ratio factor ，use mainlight's factor directioncolor *factor 
-- mode = 2  gradient ，interpolate with skycolor，midcolor，groundcolor 

ecs.component "ambient_light" { 
	mode   = "color",
	factor = 0.3,     			    
	skycolor = {1,1,1,1},
	midcolor = {1,1,1,1},
	groundcolor = {1,1,1,1},
}

