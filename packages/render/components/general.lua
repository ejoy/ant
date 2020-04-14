local ecs = ...
local assetmgr = import_package "ant.asset"

import_package "ant.math"	--import math

local fs 		= require "filesystem"
local math3d 	= require "math3d"

ecs.component_alias("parent", 	"entityid")

local respath = ecs.component_alias("respath", "string")

function respath:init()
	return fs.path(self)
end
function respath:save()
	return self:string()
end

ecs.component "rendermesh" {}

ecs.resource_component "mesh"

local meshpolicy = ecs.policy "mesh"
meshpolicy.require_component "rendermesh"
meshpolicy.require_component "mesh"
meshpolicy.require_transform "mesh_loader"

local ml = ecs.transform "mesh_loader"
ml.input    "mesh"
ml.output   "rendermesh"

function ml.process(e)
	local filename = tostring(e.mesh):gsub("[.]%w+:", ".glbmesh:")
	e.rendermesh = assetmgr.load(filename, e.mesh)
end

ecs.component "texture"
	.name "string"
	.type "string"
	["opt"].stage "int"
	["opt"].ref_path "respath"

local uniformdata = ecs.component_alias("uniformdata", "real[]")
function uniformdata:init()
	local num = #self
	if num == 4 then
		return math3d.ref(math3d.vector(self))
	elseif num == 16 then
		return math3d.ref(math3d.matrix(self))
	elseif num == 0 then
		return math3d.ref()
	else
		error(string.format("invalid uniform data, only support 4/16 as vector/matrix:%d", num))
	end
end

function uniformdata:delete()
	return {}
end

function uniformdata.save(v)
	if type(v) ~= "userdata" then
		error(string.format("must be math3d.ref data:%d", type(v)))
	end

	local d = math3d.totable(v)
	if d == nil then
		error("invalid math3d data, make sure math3d value is reference data")
	end
	assert(d.type)
	d.type = nil
	return d
end

local u = ecs.component "uniform"
	.name "string"
	.type "string"
	["opt"].value "uniformdata"
	["opt"].value_array "uniformdata[]"

function u:init()
	if self.value == nil and self.value_array == nil then
		error("uniform.value and uniform.value_array must define one of them")
	end
	return self
end

ecs.component "properties"
	["opt"].textures "texture{}"
	["opt"].uniforms "uniform{}"

ecs.resource_component "material" { multiple=true }

ecs.tag "can_render"

ecs.component_alias("name", "string", "")

local np = ecs.policy "name"
np.require_component "name"

for _, item in ipairs {
	{"blitrender", "blit_render"},
	{"render", "can_render"}
 } do
	local name, tag = item[1], item[2]
	local p = ecs.policy(name)
	p.require_component(tag)
	p.require_component "rendermesh"
	p.require_component "material"
	p.require_component "transform"
	p.require_component "scene_entity"

	p.require_system "render_system"

	p.require_policy "ant.scene|transform_policy"
end

ecs.tag "can_select"