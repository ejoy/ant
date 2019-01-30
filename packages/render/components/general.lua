local ecs = ...
local world = ecs.world
local schema = world.schema

ecs.import "ant.math"

local fs = require "filesystem"

local component_util = require "components.util"
local asset = import_package "ant.asset"
local math3d = import_package "ant.math"
local ms = math3d.stack

schema:typedef("entityid", "int", -1)

schema:typedef("path", "string")
local path = ecs.component "path"
function path:init()
	return fs.path ""
end
function path:save()
	return self:string()
end
function path:load()
	return fs.path(self)
end

schema:typedef("position", "vector")
schema:typedef("rotation", "vector")
schema:typedef("scale", "vector")

schema:type "relative_srt"
	.s "vector"
	.r "vector"
	.t "vector"

ecs.tag "editor"

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
	.filename "path"

schema:type "mesh"
	.ref_path "resource"

local mesh = ecs.component "mesh"

function mesh:load()
	self.assetinfo = asset.load(self.ref_path.package, self.ref_path.filename)
	return self
end

schema:type "texture"
	.name "string"
	.type "string"
	.stage "int"
	.ref_path "resource"	

schema:typedef("uniformdata", "real[]")

local uniformdata = ecs.component "uniformdata"
function uniformdata.save(v)
	local tt = type(v)
	if tt == "userdata" then
		local d = ms(v, "T")
		assert(d.type)
		d.type = nil
		return d
	elseif tt == "table" then
		return v
	else
		error(string.format("not support type in uniformdata:%s", tt))
	end
end

function uniformdata.load(s)
	assert(type(s) == "table")
	return s
end

schema:type "uniform"
	.name "string"
	.type "string"
	.value "uniformdata"

schema:type "properties"
	.textures "texture{}"
	.uniforms "uniform{}"

schema:type "material_content"
	.path "resource"
	.properties "properties"	

schema:type "material"
	.content "material_content[]"

local material_content = ecs.component "material_content"

function material_content:load()
	component_util.create_material(self)
	return self
end

schema:typedef("can_render", "boolean", true)
schema:typedef("can_cast", "boolean", false)
schema:typedef("name", "string", "")
ecs.tag "can_select"

local control_state = ecs.singleton_component "control_state"
function control_state:init()
	return ""
end

schema:type "parent"
	.eid "entityid"

schema:typedef("color", "real[4]", {1,1,1,1})


schema:type "character"
	.movespeed "real" (1.0)

schema:type "ambient_light"
	.mode "string" ("color")
	.factor "real" (0.3)
	.skycolor "color"
	.midcolor "color"
	.groundcolor "color"
