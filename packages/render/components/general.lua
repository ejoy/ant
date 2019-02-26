local ecs = ...
local schema = ecs.schema

ecs.import "ant.math"

local fs = require "filesystem"

local component_util = require "components.util"
local asset = import_package "ant.asset"
local math3d = import_package "ant.math"
local ms = math3d.stack

schema:typedef("path", "string")
local path = ecs.component "path"
function path:init()
	if self.string then
		return self
	end
	return fs.path(self)
end
function path:save()
	return self:string()
end

schema:typedef("point", "vector")

schema:typedef("position", "vector")
schema:typedef("rotation", "vector")
schema:typedef("scale", "vector")

schema:type "transform"
	.s "vector"
	.r "vector"
	.t "vector"

schema:typedef("srt", "transform")

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

schema:type "respath"
	.package "string"
	.filename "path"

schema:type "resource"
	.ref_path "respath" ()

local resource = ecs.component "resource"
function resource:init()
	if self.ref_path then
		self.assetinfo = asset.load(self.ref_path.package, self.ref_path.filename)
	end
	return self
end

schema:typedef("mesh", "resource")

schema:type "texture"
	.name "string"
	.type "string"
	.stage "int"
	.ref_path "respath"	

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

schema:type "uniform"
	.name "string"
	.type "string"
	.value "uniformdata"

schema:type "properties"
	["opt"].textures "texture{}"
	["opt"].uniforms "uniform{}"

schema:type "material_content"
	.ref_path "respath"
	["opt"].properties "properties"	

schema:type "material"
	.content "material_content[]"

local material_content = ecs.component "material_content"

function material_content:init()
	component_util.create_material(self)
	return self
end

schema:typedef("can_render", "boolean", true)
schema:typedef("can_cast", "boolean", false)
schema:typedef("name", "string", "")
ecs.tag "can_select"

local control_state = ecs.singleton "control_state"
function control_state:init()
	return ""
end

schema:type "parent"
	.eid "entityid"

schema:typedef("color", "real[4]", {1,1,1,1})


schema:type "character"
	.movespeed "real" (1.0)

schema:type "physic_state"
	.velocity "real[3]"
