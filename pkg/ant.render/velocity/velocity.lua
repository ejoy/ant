local ecs = ...
local world = ecs.world
local w     = world.w
local velocity_system = ecs.system "velocity_system"

local setting           = import_package "ant.settings"
local ENABLE_TAA<const> = setting:get "graphic/postprocess/taa/enable"
if not ENABLE_TAA then
    return
end

local math3d	    = require "math3d"
local bgfx		    = require "bgfx"

local hwi           = import_package "ant.hwi"
local imaterial     = ecs.require "ant.asset|material"
local RM            = ecs.require "ant.material|material"
local queuemgr      = ecs.require "queue_mgr"
local R             = world:clibs "render.render_material"
local irq           = ecs.require "ant.render|render_system.renderqueue"
local iviewport     = ecs.require "ant.render|viewport.state"
local fbmgr         = require "framebuffer_mgr"
local sampler       = import_package "ant.render.core".sampler
local default_comp  = import_package "ant.general".default

local assetmgr      = import_package "ant.asset"

local velocity_material
local velocity_polylinelist_material
local velocity_material_idx
local velocity_skinning_material

function velocity_system:end_frame()
    local mq = w:first("main_queue camera_ref:in")
    local camera <close> = world:entity(mq.camera_ref, "camera:in scene:in")
    local viewprojmat = camera.camera.viewprojmat
    for e in w:select "render_object:in visible_state:in filter_material:in polyline?in skinning?in" do
        if e.visible_state["velocity_queue"] then
            if e.polyline then
                local pl = e.polyline
                imaterial.set_property(e, "u_line_info", math3d.vector(pl.width, 0.0, 0.0, 0.0), "velocity_queue")
            elseif e.skinning then
                imaterial.set_property(e, "u_prev_vp", viewprojmat, "velocity_queue")
            else
                local mvp = math3d.mul(viewprojmat, e.render_object.worldmat)
                imaterial.set_property(e, "u_prev_mvp", mvp, "velocity_queue")
            end
        end
    end  
end

local function which_material(polylinelist, skinning)
    if polylinelist then
        return velocity_polylinelist_material.object
    end
    if skinning then
        return velocity_skinning_material.object
    end
    return velocity_material.object
end

local velocity_viewid<const> = hwi.viewid_get "velocity"

local function create_velocity_queue()
    local mq = w:first("main_queue render_target:in camera_ref:in")
    local vr = iviewport.viewrect
    world:create_entity{
        policy = {
            "ant.render|velocity_queue",
            "ant.render|watch_screen_buffer",
        },
        data = {
            camera_ref = mq.camera_ref,
            velocity_queue = true,
            render_target = {
                view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
                viewid = velocity_viewid,
                fb_idx = fbmgr.create(
                    {
                        rbidx=fbmgr.create_rb(
                        default_comp.render_buffer(
                            vr.w, vr.h, "RGBA16F", sampler {
                                RT= "RT_ON",
                                MIN="POINT",
                                MAG="POINT",
                                U="CLAMP",
                                V="CLAMP",
                            })
                        )
                    },
                    {
                        rbidx = fbmgr.get(mq.render_target.fb_idx)[2].rbidx
                    }
                ),
                view_mode = "s",
                clear_state = {
                    color = 0x000000ff,
                    clear = "C",
                },
            },
            queue_name = "velocity_queue",
            watch_screen_buffer = true,
            visible = true,
        }
    } 
end

function velocity_system:init()
    velocity_material 			    = assetmgr.resource "/pkg/ant.resources/materials/velocity/velocity.material"
    velocity_polylinelist_material  = assetmgr.resource "/pkg/ant.resources/materials/velocity/velocity_polylinelist.material"
    velocity_skinning_material      = assetmgr.resource "/pkg/ant.resources/materials/velocity/velocity_skinning.material"
    velocity_material_idx	        = queuemgr.alloc_material()
    queuemgr.register_queue("velocity_queue", velocity_material_idx)
end

function velocity_system:init_world()
    create_velocity_queue()
end

function velocity_system:update_filter()
     for e in w:select "filter_result visible_state:in render_layer:in render_object:update filter_material:in skinning?in polyline?in" do
        if e.visible_state["velocity_queue"] then
            local mo = assert(which_material(e.polyline, e.skinning))
            local ro = e.render_object
            local fm = e.filter_material
            local mi = RM.create_instance(mo)
            fm["velocity_queue"] = mi
            R.set(ro.rm_idx, queuemgr.material_index "velocity_queue", mi:ptr())
        end
    end 
end

function velocity_system:render_submit()
	bgfx.touch(velocity_viewid)
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
local mc_mb = world:sub{"main_queue", "camera_changed"}

local jitter_param = math3d.ref(math3d.vector(0.0, 0.0, 0.0, 0.0))
local jitter_cnt = 0
local jitter_origin_table = {
	[0] = {0.500000, 0.333333},
	[1] = {0.250000, 0.666667},
	[2] = {0.750000, 0.111111},
	[3] = {0.125000, 0.444444},
	[4] = {0.625000, 0.777778},
	[5] = {0.375000, 0.222222},
	[6] = {0.875000, 0.555556},
	[7] = {0.062500, 0.888889},
	[8] = {0.562500, 0.037037},
	[9] = {0.312500, 0.370370},
	[10] = {0.812500, 0.703704},
	[11] = {0.187500, 0.148148},
	[12] = {0.687500, 0.481481},
	[13] = {0.437500, 0.814815},
	[14] = {0.937500, 0.259259},
	[15] = {0.031250, 0.592593},
}

local jitter_current_table = {}

local function update_jitter_param()
	local jitter_index = jitter_cnt % 16
	local jitter = jitter_current_table[jitter_index]
	local jw, jh = jitter[1], jitter[2]
	jitter_param.v = math3d.set_index(jitter_param, 1, jw, jh)
	imaterial.system_attrib_update("u_jitter", jitter_param)
	jitter_cnt = jitter_cnt + 1
end

local function update_jitter_table()
    jitter_current_table = {}
    local vr = iviewport.viewrect
    for idx = 0, #jitter_origin_table do
        jitter_current_table[idx] = {(jitter_origin_table[idx][1] - 0.5) / vr.w * 2, (jitter_origin_table[idx][2] - 0.5) / vr.h * 2}
    end
end

function velocity_system:data_changed()
    for _, _, vr in vr_mb:unpack() do
        local vme = w:first "velocity_queue render_target:in"
        fbmgr.resize_rb(fbmgr.get(vme.render_target.fb_idx)[1].rbidx, vr.w, vr.h)
        irq.set_view_rect("velocity_queue", vr)
        update_jitter_table()
    end

    for _, _, ceid in mc_mb:unpack() do
        local e = w:first "velocity_queue camera_ref:out"
        e.camera_ref = ceid
        w:submit(e)
    end

    update_jitter_param()
end