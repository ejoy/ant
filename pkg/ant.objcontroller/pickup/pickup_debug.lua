local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr

local mathpkg	= import_package "ant.math"
local mu		= mathpkg.util

local ientity   = ecs.require "ant.entity|entity"
local imaterial = ecs.require "ant.render|material"
local ivm		= ecs.require "ant.render|visible_mask"

local frustum_entity
local function create_frustum_entity()
	local pq = w:first("pickup_queue camera_ref:in")
	local camera <close> = world:entity(pq.camera_ref, "camera:in")
	local points = math3d.frustum_points(camera.camera.viewprojmat)
	return ientity.create_frustum_entity(points)
end

local pickup_debug_sys = ecs.system "pickup_debug_system"

local function create_view_buffer_entity()
	local m = ientity.quad_mesh(mu.texture_uv{x=0,y=0,w=120, h=120})
	world:create_entity{
		policy = {
			"ant.render|simplerender",
		},
		data = {
			mesh_result = m,
			material = "/pkg/ant.resources/materials/texquad.material",
			visible = true,
			render_layer = "translucent",
			scene = {},
			on_ready = function (e)
				local pq = w:first("pickup_queue render_target:in")
				local rt = pq.render_target
				imaterial.set_property(e, "s_tex", fbmgr.get_rb(rt.fb_idx, 1).handle)
			end,
		}
	}
end

function pickup_debug_sys:init()
    create_view_buffer_entity()
end

local function log_pickup_queue_entities()
	log.info "pickup queue entities:"
	local entities = {}
	for e in w:select "visible eid:input" do
		if ivm.check(e, "pickup_queue") then
			entities[#entities+1] = ("%d"):format(e.eid)
		end
	end

	log.info(table.concat(entities, "\t"))
end


local mousemb = world:sub{"mouse"}

function pickup_debug_sys:data_changed()
    for _, btn, state in mousemb:unpack() do
        if btn == "LEFT" and state == "DOWN" then
            if frustum_entity then
                w:remove(frustum_entity)
                frustum_entity = nil
            end
        end
    end

	log_pickup_queue_entities()
end

function pickup_debug_sys:camera_usage()
    if frustum_entity == nil then
        frustum_entity = create_frustum_entity()
    end
end
