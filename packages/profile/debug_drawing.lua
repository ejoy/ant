local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local fs = require "filesystem"

local componentutil = import_package "ant.render".components


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
ecs.tag "debug_skeleton"

local debug_obj = ecs.singleton "debug_object"

local function clean_desc_buffer(desc)
	desc.material = ""
	desc.vb={}
	desc.ib={}
	desc.primitives = {}
end

function debug_obj:init()
	local self = {}
	self.renderobjs = {
		wireframe = {
			desc = {}			
		}
	}

	clean_desc_buffer(self.renderobjs.wireframe.desc)

	local debugeid = world:create_entity {
		transform = {		
			s = {1, 1, 1, 0},
			r = {0, 0, 0, 0},
			t = {0, 0, 0, 1},
		},
		mesh = {},
		material = {
			content = {
				{
					ref_path = fs.path "//ant.resources/line.material"
				}				
			}
		},
		main_debug = true,
		can_render = true, 
		name = "debug_test",
		main_viewtag = true,
	}

	local dbentity = world[debugeid]
	dbentity.mesh = {
		assetinfo={handle=init_wireframe_mesh()}
	}
	return self
end

local debug_draw = ecs.system "debug_draw"
debug_draw.singleton "debug_object"

local function check_add_material(mc, materialpath)
	local function has_material()
		for _, m in ipairs(mc) do
			if m.path == materialpath then
				return true
			end
		end
	end

	if not has_material() then		
		componentutil.add_material(mc, materialpath)
	end
end

function debug_draw:update()
	local dbgobj = self.debug_object

	local renderobjs = dbgobj.renderobjs

	local wireframe = renderobjs.wireframe

	local dbentity = world:first_entity("main_debug")
	local mc = dbentity.material.content
	local meshgroups = dbentity.mesh.assetinfo.handle.groups

	local function commit_desc(desc)	
		if desc.vb == nil or next(desc.vb) == nil then
			return false
		end
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

		clean_desc_buffer(desc)
		return true
	end

	dbentity.can_render = commit_desc(assert(wireframe.desc))
end

