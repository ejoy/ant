local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local componentutil = require "render.components.util"
local mu = require "math.util"

local function init_wireframe_mesh()
	local decl, vertexsize = bgfx.vertex_decl {
		{ "POSITION", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
	}
	return	{
		groups={
			{
				vb={
					decls={	{decl, vertexsize}, },
					handles={
						bgfx.create_dynamic_vertex_buffer(1024*10, decl, "a")
					}
				},
				ib={
					handle=bgfx.create_dynamic_index_buffer(1024*10, "a")
				},
				primitives={}
			},
		}
	}	
end

ecs.tag "main_debug"

local debug_obj = ecs.component "debug_object" {
	type = "userdata",
	default = {}
}

function debug_obj:init()
	self.renderobjs = {
		wireframe = {
			desc = {
				material = "",
				vb={},
				ib={},
				primitives = {},
			},
		}
	}

	local debugeid = world:new_entity("position", "scale", "rotation",
	"mesh", "material",
	"main_debug",
	"can_render", "name")

	local dbentity = world[debugeid]

	dbentity.name = "debug_test"	

	dbentity.mesh = {
		assetinfo={handle=init_wireframe_mesh()}
	}

	componentutil.load_material(dbentity.material, {"line.material"})
end

local debug_draw = ecs.system "debug_draw"
debug_draw.singleton "debug_object"
debug_draw.singleton "math_stack"

local function check_add_material(mc, materialpath)
	local function has_material()
		for _, m in ipairs(mc) do
			if m.path == materialpath then
				return true
			end
		end
	end

	if not has_material() then
		local m = {}
		table.insert(mc, componentutil.create_material(materialpath, m))
	end
end

function debug_draw:update()
	local dbgobj = self.debug_object

	local renderobjs = dbgobj.renderobjs

	local wireframe = renderobjs.wireframe

	local dbentity = world:first_entity("main_debug")
	local mc = dbentity.material.content
	local meshgroups = dbentity.mesh.assetinfo.handle.groups

	local ms = self.math_stack
	mu.identify_transform(ms, dbentity)
	
	local function commit_desc(desc)		
		local materialpath = desc.material
		if materialpath and materialpath ~= "" then
			check_add_material(mc, materialpath)
		end

		local g = meshgroups[1]

		local prim = g.primitives
		table.move(desc.primitives, 1, #desc.primitives, #prim+1, prim)

		local gvb = assert(g.vb)
		
		local dvb = desc.vb		
		local vbuffer = {"fffd"}
		for _, v in ipairs(dvb) do
			table.move(v, 1, #v, #vbuffer+1, vbuffer)
		end

		bgfx.update(gvb.handles[1], 0, vbuffer)
		bgfx.update(assert(g.ib).handle, 0, desc.ib)
	end

	commit_desc(assert(wireframe.desc))
end

