local ecs = ...

ecs.import "ant.math"

local fs = require "filesystem"

local component_util = require "components.util"
local asset = import_package "ant.asset".mgr
local math3d = import_package "ant.math"
local ms = math3d.stack


ecs.component_alias("point", "vector")
ecs.component_alias("position", "vector")
ecs.component_alias("rotation", "vector")
ecs.component_alias("scale", "vector")

ecs.component "srt"
	.s "vector"
	.r "vector"
	.t "vector"

ecs.component "transform"
	.s "vector"
	.r "vector"
	.t "vector"
	['opt'].slotname "string"
	['opt'].parent "parent"

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

function resource:init()
	if self.ref_path then
		self.assetinfo = asset.load(self.ref_path)
	end
	return self
end

ecs.component "submesh_ref"
	.material_refs "int[]"
	.visible "boolean"

local mesh = ecs.component "mesh"
	["opt"].ref_path "respath"
	["opt"].submesh_refs "submesh_ref{}"
	.lodidx "int" (1)

local function check_mesh_lod(mesh)
	local scene = mesh.assetinfo.handle
	if scene.scenelods then
		assert(0 <= scene.scene < scene.scenelods)
		if mesh.lodidx <= 0 or mesh.lodidx > #scene.scenelods then
			print("invalid lod:", mesh.lodidx, "max lod:", scene.scenelods)
			mesh.lodidx = 1
		end
	else
		if scene.scene ~= mesh.lodidx - 1 then
			print("default lod scene is not equal to lodidx")
		end
	end
end

function mesh:init()
	if self.ref_path then
		self.assetinfo = asset.load(self.ref_path)
		self.lodidx = self.lodidx or 1
		check_mesh_lod(self)
	end
	return self
end

function mesh:delete()
	local scene = self.assetinfo
	if scene then
		for _, bv in ipairs(scene.bufferViews) do
			if bv.handle then
				bgfx.destroy(bv.handle)
				bv.handle = nil
			end
		end
	end
end

ecs.component_alias("new_mesh", "mesh")

local tex = ecs.component "texture"
	.name "string"
	.type "string"
	.stage "int"
	.ref_path "respath"

function tex:delete()
	if tex.handle then
		bgfx.destroy(tex.handle)
		tex.handle = nil
	end
end

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

local material_content = ecs.component "material_content"
	.ref_path "respath"
	["opt"].properties "properties"	

function material_content:init()
	component_util.create_material(self)
	return self
end

ecs.component "material"
	.content "material_content[]"


ecs.component_alias("can_render", "boolean", true) {depend={"transform", "mesh", "material"}}
ecs.component_alias("can_cast", "boolean", false)
ecs.component_alias("name", "string", "")
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