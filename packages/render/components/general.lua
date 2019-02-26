local ecs = ...

ecs.import "ant.math"

local fs = require "filesystem"

local component_util = require "components.util"
local asset = import_package "ant.asset"
local math3d = import_package "ant.math"
local ms = math3d.stack

local path = ecs.component_alias("path", "string")

function path:init()
	if self.string then
		return self
	end
	return fs.path(self)
end
function path:save()
	return self:string()
end


ecs.component_alias("point", "vector")
ecs.component_alias("position", "vector")
ecs.component_alias("rotation", "vector")
ecs.component_alias("scale", "vector")

ecs.component "transform"
	.s "vector"
	.r "vector"
	.t "vector"

ecs.component_alias("srt", "transform")

ecs.tag "editor"

ecs.component "frustum"
	.type "string" ("mat")
	.n "real" (0.1)
	.f "int" (10000)
	.l "int" (-1)
	.r "int" (1)
	.t "int" (1)
	.b "int" (-1)
	.ortho "boolean" (false)

ecs.component "respath"
	.package "string"
	.filename "path"

local resource = ecs.component "resource"
	.ref_path "respath" ()

function resource:init()
	if self.ref_path then
		self.assetinfo = asset.load(self.ref_path.package, self.ref_path.filename)
	end
	return self
end

ecs.component_alias("mesh", "resource")

ecs.component "texture"
	.name "string"
	.type "string"
	.stage "int"
	.ref_path "respath"	

local uniformdata = ecs.component_alias("uniformdata", "real[]")

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

ecs.component "uniform"
	.name "string"
	.type "string"
	.value "uniformdata"

ecs.component "properties"
	["opt"].textures "texture{}"
	["opt"].uniforms "uniform{}"

local material_content = ecs.component "material_content"
	.ref_path "respath"
	["opt"].properties "properties"	

function material_content:init()
	component_util.create_material(self)
	return self
end

ecs.component "material"
	.content "material_content[]"


ecs.component_alias("can_render", "boolean", true)
ecs.component_alias("can_cast", "boolean", false)
ecs.component_alias("name", "string", "")
ecs.tag "can_select"

local control_state = ecs.singleton "control_state"
function control_state:init()
	return ""
end

ecs.component "parent"
	.eid "entityid"

ecs.component_alias("color", "real[4]", {1,1,1,1})


ecs.component "character"
	.movespeed "real" (1.0)

ecs.component "physic_state"
	.velocity "real[3]"
