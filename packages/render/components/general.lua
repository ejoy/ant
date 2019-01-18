local ecs = ...
local world = ecs.world
local schema = world.schema

schema:typedef("tag", "boolean", true)

schema:userdata "ud_vector"
schema:userdata "ud_path"

schema:typedef("position", "ud_vector")
schema:typedef("rotation", "ud_vector")
schema:typedef("scale", "ud_vector")

schema:type "relative_srt"
	.s "ud_vector"
	.r "ud_vector"
	.t "ud_vector"

schema:typedef("editor", "tag")

schema:type "frustum"
	.type "string" ("mat")
	.n "real" (0.1)
	.f "int" (10000)
	.l "int" (-1)
	.r "int" (1)
	.t "int" (1)
	.b "int" (-1)
	.ortho "boolean" (false)

schema:typedef("viewid", "int", 0)

schema:type "resource"
	.package "string"
	.filename "ud_path"

schema:type "mesh"
	.ref_path "resource"

schema:type "material_content"
	.path "ud_path"

schema:type "material"
	.content "material_content[]"

schema:typedef("can_render", "boolean", true)
schema:typedef("can_cast", "boolean", false)
schema:typedef("name", "string", "")
schema:typedef("can_select", "tag")
schema:typedef("control_state", "string", "")

schema:type "parent"
	.eid "int" (-1)

schema:typedef("color", "int[4]", {1,1,1,1})

schema:type "ambient_light"
	.mode "string" ("color")
	.factor "real" (0.3)
	.skycolor "color"
	.midcolor "color"
	.groundcolor "color"

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

local ComponentType = {}
function ComponentType.path()
	return {
		__type = "path",
		init = function()
			return {}
		end,
		save = function(v)
			v[2] = v[2]:string()
			return v
		end,
		load = function(v)
			v[2] = fs.path(v[2])
			return v
		end,
	}
end

function ComponentType.array(typeinfo)
	return {
		__type = "array",
		init = function()
			return {}
		end,
		pairs = function(c)
			local i = 0
			return function ()
				i = i + 1
				if c[i] then
					return i, typeinfo
				end
			end
		end,
	}
end


function ComponentType.raw()
	return {
		__type = "raw",
		init = function()
			return {}
		end,
		save = function(v)
			return v
		end,
		load = function(v)
			return v
		end,
	}
end

local mesh = ecs.component "mesh" {
	ref_path = ComponentType.path()
}

function mesh:save(arg)
	assert(type(self.ref_path[2]) == "string")
	local world = arg.world
	local e = assert(world[arg.eid])
	local comp = assert(e[arg.comp])
	assert(comp.assetinfo)
	return self
end

function mesh:load()
	assert(self.assetinfo == nil)
	assert(type(self.ref_path[2]) == "table")
	self.assetinfo = asset.load(self.ref_path[1], self.ref_path[2])
	return self
end

local material = ecs.component "material" {
	content = ComponentType.array({
		path = ComponentType.path(),
		properties = ComponentType.raw()
	})
}

function material:save()
	for _, e in ipairs(self.content) do
		local pp = assert(e.path)
		assert(pp ~= "")

		local assetcontent = asset.load(pp[1], fs.path(pp[2]))
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
	end
	return self
end

function material:load()
	local m = {}
	for _, e in ipairs(self.content) do
		component_util.add_material(m, e.path[1], e.path[2])
	end
	return m
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

