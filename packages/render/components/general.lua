local ecs = ...
local world = ecs.world

local mathpkg 	= import_package "ant.math"
local ms 		= mathpkg.stack

local component_util = require "components.util"

local fs 		= require "filesystem"
local math3d 	= require "math3d"

ecs.component_alias("parent", 	"entityid")
ecs.component_alias("point", 	"vector")
ecs.component_alias("position", "vector")
ecs.component_alias("rotation", "vector")
ecs.component_alias("scale", 	"vector")

ecs.component "srt"
	.s "vector"
	.r "vector"
	.t "vector"

local trans = ecs.component "transform"
	.s "vector"
	.r "vector"
	.t "vector"
	['opt'].slotname "string"
	['opt'].parent "parent"

function trans:init()
	if self.parent then
		local pe = world[self.parent]
		if pe == nil then
			error(string.format("tranform specified parent eid, but parent eid is not exist : %d", self.parent))
		else
			if pe.hierarchy == nil then
				error(string.format("transform specified parent eid, but parent entity is not a hierarchy entity, parent eid: %d", self.parent))
			end
		end
	end

	self.world = math3d.ref "matrix"
	ms(self.world, ms:srtmat(self), "=")
	return self
end

function trans:delete()
	if self.world then
		self.world(nil)
	end
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
	.material_refs "int[]"
	.visible "boolean"

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


ecs.component_alias("can_render", "boolean", true)
ecs.component_alias("can_cast", "boolean", false)
ecs.component_alias("name", "string", "")

local gp = ecs.policy "name"
gp.require_component "name"

local renderpolicy = ecs.policy "render"
renderpolicy.require_component "can_render"
renderpolicy.require_component "rendermesh"
renderpolicy.require_component "material"
renderpolicy.require_component "transform"

renderpolicy.require_system "render_system"

ecs.tag "can_select"

local control_state = ecs.singleton "control_state"
function control_state:init()
	return ""
end

ecs.component_alias("color", "real[4]", {1,1,1,1})

ecs.tag "dynamic_object"
ecs.component "character"
	.movespeed "real" (1.0)

ecs.component "physic_state"
	.velocity "real[3]"

local constant = ecs.singleton "constant"
function constant.init()
	return {
		tcolors = {

		}
	}
end