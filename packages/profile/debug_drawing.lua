local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local fs = require "filesystem"
local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr
local computil = renderpkg.components

local function init_wireframe_mesh()
	local decl = declmgr.get("p3|c40niu")
	return	computil.create_dynamic_mesh_handle(decl.handle, 1024*10, 1024*10)
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
		assetinfo=init_wireframe_mesh()
	}
	return wo
end

local debug_draw = ecs.system "debug_draw"
debug_draw.singleton "wireframe_object"

function debug_draw:init()
	
end

function debug_draw:update()
	
end

