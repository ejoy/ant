local ecs = ...
local world = ecs.world

local component_util = require "components.util"

local fs 		= require "filesystem"
local math3d 	= require "math3d"

ecs.component_alias("parent", 	"entityid")
ecs.component_alias("point", 	"vector")
ecs.component_alias("rotation", "quaternion",{0,0,0,1})
ecs.component_alias("scale",	"vector")
ecs.component_alias("position",	"vector")
ecs.component_alias("direction", "vector")

ecs.component "transform"
	.srt "srt"
	['opt'].slotname "string"
	['opt'].parent "parent"

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

local sm_ref = ecs.component "submesh_ref"
	["opt"].material_refs "int[]"
	.visible "boolean"
function sm_ref:init()
	if self.visible and self.material_refs == nil then
		error(string.format("submesh is visible, but material_refs is nil"))
	end
	return self
end

local rendermesh = ecs.component "rendermesh"
	["opt"].submesh_refs "submesh_ref{}"
	["opt"].lodidx "int" (1)

function rendermesh:init()
	self.lodidx = self.lodidx or 1
	return self
end

ecs.component "mesh"
	.ref_path "respath" ()

local meshpolicy = ecs.policy "mesh"
meshpolicy.require_component "rendermesh"
meshpolicy.require_component "mesh"
meshpolicy.require_transform "mesh_loader"

local ml = ecs.transform "mesh_loader"
ml.input    "mesh"
ml.output   "rendermesh"

function ml.process(e)
    component_util.create_mesh(e.rendermesh, e.mesh)
end

--DO NOT define init/delete function to manager texture resource
--texture should only create/remove from material component, see material component definition
ecs.component "texture"
	.name "string"
	.type "string"
	.stage "int"
	.ref_path "respath"

local uniformdata = ecs.component_alias("uniformdata", "real[]")

function uniformdata.save(v)
	local tt = type(v)
	if tt == "userdata" then
		local d = math3d.totable(v)
		assert(d.type)
		d.type = nil
		return d
	elseif tt == "table" then
		return v
	else
		error(string.format("not support type in uniformdata:%s", tt))
	end
end

function uniformdata.delete(v)
	local tt = type(v)
	if tt == "userdata" then
		v(nil)
	end
end

ecs.component "uniform"
	.name "string"
	.type "string"
	.value "uniformdata"

ecs.component "properties"
	["opt"].textures "texture{}"
	["opt"].uniforms "uniform{}"

ecs.component "material" { multiple=true }
	.ref_path "respath"
	["opt"].properties "properties"


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

ecs.component_alias("color", "real[4]", {1,1,1,1})

ecs.tag "dynamic_object"

ecs.component "physic_state"
	.velocity "real[3]"
