local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr

local ientity   = ecs.import.interface "ant.render|ientity"
local imesh     = ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"



local frustum_entity
local function create_frustum_entity()
	local pq = w:singleton("pickup_queue", "camera_ref:in")
	local cref = world:entity(pq.camera_ref)
	local points = math3d.frustum_points(cref.camera.viewprojmat)
	return ientity.create_frustum_entity(points, "pickup_frustum")
end

local pickup_debug_sys = ecs.system "pickup_debug_system"

local function create_view_buffer_entity()
	ecs.create_entity{
		policy = {
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
			name = "pick_buffer_entity",
			simplemesh = imesh.init_mesh(ientity.quad_mesh{x=0,y=0,w=120, h=120}, true),
			material = "/pkg/ant.resources/materials/texquad.material",
			material_setting = {POS_IN_RECT=1},
			filter_state = "main_view",
			scene = {srt={}},
			on_ready = function (e)
				local pq = w:singleton("pickup_queue", "render_target:in")
				local rt = pq.render_target
				w:sync("render_object:in", e)
				imaterial.set_property(e, "s_tex", {stage=0, texture={handle=fbmgr.get_rb(rt.fb_idx, 1).handle}})
			end,
		}
	}
end

function pickup_debug_sys:init()
    create_view_buffer_entity()
end


local mousemb = world:sub{"mouse"}

function pickup_debug_sys:data_changed()
    for _, btn, state in mousemb:unpack() do
        if btn == "LEFT" and state == "DOWN" then
            if frustum_entity then
                world:remove_entity(frustum_entity)
                frustum_entity = nil
            end
        end
    end
end

function pickup_debug_sys:camera_usage()
    if frustum_entity == nil then
        frustum_entity = create_frustum_entity()
    end
end
