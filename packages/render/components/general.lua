local ecs = ...

ecs.import "ant.math"

local fs = require "filesystem"

local component_util = require "components.util"
local asset = import_package "ant.asset".mgr
local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local math3d = require "math3d"


ecs.component_alias("point", "vector")
ecs.component_alias("position", "vector")
ecs.component_alias("rotation", "vector")
ecs.component_alias("scale", "vector")

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
	self.world = math3d.ref "matrix"
	ms(self.world, ms:srtmat(self), "=")
	return self
end

ecs.tag "editor"

ecs.component "frustum"
	.type "string" ("mat")
	.n "real" (0.1)
	.f "real" (10000)
	['opt'].l "real" (-1)
	['opt'].r "real" (1)
	['opt'].t "real" (1)
	['opt'].b "real" (-1)
	['opt'].aspect "real" (1)
	['opt'].fov "real" (1)
	.ortho "boolean" (false)

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

local resource = ecs.component "resource"
	.ref_path "respath" ()
	["opt"].asyn_load "boolean" (false)

function resource:init()
	if not self.asyn_load then
		asset.load(self.ref_path)
	end
	return self
end

function resource:postinit(e)
	if not self.asyn_load then
		assert(e.asyn_load == nil)
	end
end

function resource:delete()
	asset.unload(self.ref_path)
	self.ref_path = nil
end

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

function rendermesh:delete()
	self.reskey = nil
end

local mesh = ecs.component "mesh" {depend="rendermesh"}
	.ref_path "respath" ()
	["opt"].asyn_load "boolean" (false)

function mesh:init()
	return self
end
function mesh:postinit(e)
	if not self.asyn_load then
		assert(e.asyn_load == nil)
		component_util.create_mesh(e.rendermesh, self)
	end
end

function mesh:delete(e)
	component_util.remove_mesh(e.rendermesh, self)
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

local material = ecs.component "material" { multiple=true }
	.ref_path "respath"
	["opt"].properties "properties"
	["opt"].asyn_load "boolean" (false)

function material:init()
	if not self.asyn_load then
		component_util.create_material(self)
	end
	return self
end

function material:delete()
	component_util.remove_material(self)
end

ecs.component_alias("can_render", "boolean", true) {depend={"transform", "rendermesh", "material"}}
ecs.component_alias("can_cast", "boolean", false)
ecs.component_alias("name", "string", "")

local asynload_state = ecs.component_alias("asyn_load", "string", "") {depend={"mesh", "material"}}
function asynload_state.init()
	return ""	-- always true
end

function asynload_state:postinit(e)
	assert(self == "")
	assert(e.mesh.asyn_load)
	for _, m in ipairs(e.material) do
		assert(m.asyn_load)
	end
end

function asynload_state.save()
	return ""	--always save empty string
end

ecs.tag "can_select"

local control_state = ecs.singleton "control_state"
function control_state:init()
	return ""
end

ecs.component_alias("parent", "entityid")
ecs.component_alias("color", "real[4]", {1,1,1,1})


ecs.component "character"
	.movespeed "real" (1.0)

ecs.component "physic_state"
	.velocity "real[3]"

local constant = ecs.singleton "constant"
function constant.init()
	return {
		tcolors = {
			red = {1, 0, 0, 1},
			green = {0, 1, 0, 1},
			blue = {0, 0, 1, 1},
			black = {0, 0, 0, 1},
			white = {1, 1, 1, 1},
			yellow = {1, 1, 0, 1},
			gray = {0.5, 0.5, 0.5, 1},
		}
	}
end

local mqdata = ecs.singleton "mian_queue_data"