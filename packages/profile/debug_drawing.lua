local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local fs = require "filesystem"

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

ecs.tag "debug_wireframe"
ecs.tag "debug_obj"

local wireframe_obj = ecs.singleton "wireframe_object"

local function clean_desc_buffer(desc)
	desc.material = ""
	desc.vb={}
	desc.ib={}
	desc.primitives = {}
end

function wireframe_obj.init(self)
	local wo = {}
	wo.renderobjs = {
		wireframe = {
			desc = {}			
		}
	}

	clean_desc_buffer(wo.renderobjs.wireframe.desc)

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
		can_render = true, 
		name = "wireframe_obj",
		main_view = true,
	}

	local dbentity = world[debugeid]
	dbentity.mesh = {
		assetinfo={handle=init_wireframe_mesh()}
	}
	return wo
end

local debug_draw = ecs.system "debug_draw"
debug_draw.singleton "wireframe_object"

function debug_draw:init()
	
end

function debug_draw:update()
	
end

