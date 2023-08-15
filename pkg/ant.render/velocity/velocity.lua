local ecs = ...
local world = ecs.world
local w     = world.w
local velocity_system = ecs.system "velocity_system"
local math3d	= require "math3d"
local bgfx		= require "bgfx"

local hwi       = import_package "ant.hwi"
local imaterial = ecs.require "ant.asset|material"
local queuemgr  = ecs.require "queue_mgr"
local R         = ecs.clibs "render.render_material"
local irq       = ecs.require "ant.render|render_system.renderqueue"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"
local default_comp 	= import_package "ant.general".default
local velocity_material
local velocity_polylinelist_material
local velocity_material_idx
local mathpkg	= import_package "ant.math"
local renderutil = require "util"
local mc		= mathpkg.constant
local velocity_skinning_material
local setting = import_package "ant.settings".setting
local ENABLE_TAA<const> = setting:data().graphic.postprocess.taa.enable
if not ENABLE_TAA then
    renderutil.default_system(velocity_system, "init", "init_world", "update_filter", "data_changed", "end_frame", "render_submit")
    return
end

function velocity_system:end_frame()
    local mq = w:first("main_queue camera_ref:in")
    local camera <close> = w:entity(mq.camera_ref, "camera:in scene:in")
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
    local vp = world.args.viewport
    ecs.create_entity{
        policy = {
            "ant.general|name",
            "ant.render|velocity_queue",
            "ant.render|watch_screen_buffer",
        },
        data = {
            camera_ref = mq.camera_ref,
            velocity_queue = true,
            render_target = {
                view_rect = {x=vp.x, y=vp.y, w=vp.w, h=vp.h},
                viewid = velocity_viewid,
                fb_idx = fbmgr.create(
                    {
                        rbidx=fbmgr.create_rb(
                        default_comp.render_buffer(
                            vp.w, vp.h, "RGBA16F", sampler {
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
            name = "velocity_queue",
            visible = true,
        }
    } 
end

function velocity_system:init()
    velocity_material 			= imaterial.load_res "/pkg/ant.resources/materials/velocity/velocity.material"
    velocity_polylinelist_material = imaterial.load_res "/pkg/ant.resources/materials/velocity/velocity_polylinelist.material"
    velocity_skinning_material = imaterial.load_res "/pkg/ant.resources/materials/velocity/velocity_skinning.material"
    velocity_material_idx	    = queuemgr.alloc_material()
    queuemgr.register_queue("velocity_queue", velocity_material_idx)
end

function velocity_system:init_world()
    create_velocity_queue()
end

function velocity_system:update_filter()
     for e in w:select "filter_result visible_state:in render_layer:in render_object:update filter_material:in skinning?in name?in" do
        if e.visible_state["velocity_queue"] then
            local polylinelist
            if e.name and e.name == "polyline" then
                polylinelist = true
            end
            local mo = assert(which_material(polylinelist, e.skinning))
            local ro = e.render_object
            local fm = e.filter_material
            local mi = mo:instance()
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
	local sa = imaterial.system_attribs()
	local jitter_index = jitter_cnt % 16
	local jitter = jitter_current_table[jitter_index]
	local jw, jh = jitter[1], jitter[2]
	jitter_param.v = math3d.set_index(jitter_param, 1, jw, jh)
	sa:update("u_jitter", jitter_param)
	jitter_cnt = jitter_cnt + 1
end

local function update_jitter_table()
    jitter_current_table = {}
    local vp = world.args.viewport
    for idx = 0, #jitter_origin_table do
        jitter_current_table[idx] = {(jitter_origin_table[idx][1] - 0.5) / vp.w * 2, (jitter_origin_table[idx][2] - 0.5) / vp.h * 2}
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