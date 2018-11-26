local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local componentutil = require "components.util"

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
				}
			},
		}
	}	
end

local debug_obj = ecs.component "debug_object" {}

ecs.tag "main_debug"

function debug_obj:init()
	self.renderobjs = {
		wireframe = {
			desc = {},
			-- desc = {
			-- 	material = "",
			-- 	vb={},
			-- 	ib={},
			-- 	primitives = {
			-- 		{
			-- 			voffset=0, vnum=40,
			-- 			ioffset=0, inum=40,
			-- 		},
			-- 	},
			-- },
		}
	}

	local debugeid = world:new_entity("position", "scale", "rotation",
	"mesh", "material",
	"main_debug",
	"can_render", "name")

	local debugobj = world[debugeid]
	debugobj.mesh = {
		assetinfo={handle=init_wireframe_mesh()}
	}
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
		table.insert(mc, componentutil.create_material(materialpath))
	end
end

function debug_draw:update()
	local dbgobj = self.debug_object

	local renderobjs = dbgobj.renderobjs

	local wireframe = renderobjs.wireframe

	local debugobj = world:first_entity("main_debug")
	local mc = debugobj.material.content
	local meshgroups = debugobj.mesh.handle.groups
	
	for _, ro in ipairs(wireframe) do
		local desc = assert(ro.desc)
		local materialpath = desc.material
		if materialpath and materialpath ~= "" then
			check_add_material(mc, materialpath)
		end

		local g = meshgroups[1]
		local prim = g.prim

		local gvb = assert(g.vb)
		local h = gvb.handles[1]
		local decl = gvb.decl[1]
		local ih = assert(g.ib).handle

		local dvb = desc.vb
		local vnum = #dvb
		local vbuffer = {}
		for _, v in ipairs(dvb) do
			table.move(v, 1, #v, #vbuffer+1, vbuffer)
		end

		local dib = desc.ib
		local inum = #dib
		local ibuffer = {}
		for _, i in ipairs(dib) do
			table.move(i, 1, #i, #ibuffer+1, ibuffer)
		end

		for _, p in ipairs(desc.primitives) do
			table.insert(prim, p)
		end

		bgfx.update(h, 0, {"fffd", vbuffer, vnum * decl.vertexsize})
		bgfx.update(ih, 0, {ibuffer, inum * 2})
	end
end

