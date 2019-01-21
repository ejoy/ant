local ecs = ...
local world = ecs.world
local schema = world.schema

ecs.import "ant.math"

local fs = require "filesystem"

local component_util = require "components.util"
local asset = import_package "ant.asset"

schema:typedef("entityid", "int", -1)

schema:userdata "path"
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

schema:type "property"
	.name "string"
	.type "string"
	.stage "int"

schema:type "material_content"
	.path "resource"
	.properties "property{}"

schema:type "material"
	.content "material_content[]"

local material_content = ecs.component "material_content"

function material_content:save()
	local pp = assert(self.path)
	assert(pp ~= "")
	local assetcontent = asset.load(pp.package, fs.path(pp.filename))
	local src_properties = assetcontent.properties
	if src_properties then
		local properties = {}
		for k, v in pairs(src_properties) do
			local p = self.properties[k]
			local type = p.type
			if type == "texture" then
				properties[k] = {name=p.name, type=type, path=v.default, stage=p.stage}
			else
				properties[k] = p
			end
		end
		self.properties = properties
	end
	return self
end

function material_content:load()
	component_util.create_material(self)
	return self
end

schema:typedef("can_render", "boolean", true)
schema:typedef("can_cast", "boolean", false)
schema:typedef("name", "string", "")
ecs.tag "can_select"
schema:typedef("control_state", "string", "")

schema:type "parent"
	.eid "entityid"

schema:typedef("color", "int[4]", {1,1,1,1})

schema:type "ambient_light"
	.mode "string" ("color")
	.factor "real" (0.3)
	.skycolor "color"
	.midcolor "color"
	.groundcolor "color"
