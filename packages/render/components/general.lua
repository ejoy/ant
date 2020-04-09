local ecs = ...
local assetmgr = import_package "ant.asset"

local fs 		= require "filesystem"
local math3d 	= require "math3d"

ecs.component_alias("parent", 	"entityid")
ecs.component_alias("point", 	"vector")
ecs.component_alias("rotation", "quaternion",{0,0,0,1})
ecs.component_alias("scale",	"vector")
ecs.component_alias("position",	"vector")
ecs.component_alias("direction", "vector")

local trans = ecs.component "transform"
	.srt "srt"
	['opt'].slotname "string"
	['opt'].parent "parent"
function trans:init()
	self.world = math3d.ref(self.srt)
	return self
end

ecs.tag "editor"

ecs.component "frustum"
	['opt'].type "string" ("mat")
	.n "real" (0.1)
	.f "real" (10000)
	['opt'].l "real" (-1)
	['opt'].r "real" (1)
	['opt'].t "real" (1)
	['opt'].b "real" (-1)
	['opt'].aspect "real" (1)
	['opt'].fov "real" (1)
	['opt'].ortho "boolean" (false)

local respath = ecs.component_alias("respath", "string")

function respath:init()
	if self.string then
		return self
	end
	return fs.path(self)
end
function respath:save()
	return self:string()
end

ecs.component "resource"
	.ref_path "respath"

ecs.component "submesh_ref"
	["opt"].material_refs "int[]"
	.visible "boolean"

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
ecs.tag "can_cast"
ecs.component_alias("name", "string", "")

local gp = ecs.policy "name"
gp.require_component "name"

local blitpolicy = ecs.policy "blitrender"
blitpolicy.require_component "blit_render"
blitpolicy.require_component "rendermesh"
blitpolicy.require_component "material"
blitpolicy.require_component "transform"

local renderpolicy = ecs.policy "render"
renderpolicy.require_component "can_render"
renderpolicy.require_component "rendermesh"
renderpolicy.require_component "material"
renderpolicy.require_component "transform"

renderpolicy.require_system "render_system"
renderpolicy.require_policy "blitrender"

ecs.tag "can_select"

ecs.component_alias("color", "vector", {1,1,1,1})

ecs.tag "dynamic_object"

ecs.component "physic_state"
	.velocity "real[3]"
