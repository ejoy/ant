local ecs = ...
local world = ecs.world
local w     = world.w
local velocity_system = ecs.system "velocity_system"
local math3d	= require "math3d"
local bgfx		= require "bgfx"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local viewidmgr = require "viewid_mgr"
local queuemgr      = require "queue_mgr"
local R             = ecs.clibs "render.render_material"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"
local default_comp 	= import_package "ant.general".default
local velocity_material
local velocity_polylinelist_material
local velocity_material_idx

function velocity_system:end_frame()
    local mq = w:first("main_queue camera_ref:in")
    local camera <close> = w:entity(mq.camera_ref, "camera:in scene:in")
    local viewprojmat = camera.camera.viewprojmat
    for e in w:select "render_object:in visible_state:in filter_material:in polyline?in" do
        if e.visible_state["velocity_queue"] then
            local mvp = math3d.mul(viewprojmat, e.render_object.worldmat)
            imaterial.set_property(e, "u_prev_mvp", mvp, "velocity_queue")
            if e.polyline then
                local pl = e.polyline
                imaterial.set_property(e, "u_line_info", math3d.vector(pl.width, 0.0, 0.0, 0.0), "velocity_queue")
                --imaterial.set_property(e, "u_color", pl.color, "velocity_queue")
            end
        end
    end  
end

local function which_material(polylinelist)
    if polylinelist then
        return velocity_polylinelist_material.object
    end
    return velocity_material.object
end

local function create_velocity_queue()
    local mq = w:first("main_queue render_target:in camera_ref:in")
    local vp = world.args.viewport
    local viewid = viewidmgr.get "velocity"
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
                viewid = viewid,
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
    velocity_material_idx	    = queuemgr.alloc_material()
    queuemgr.register_queue("velocity_queue", velocity_material_idx)
end

function velocity_system:init_world()
    create_velocity_queue()
end

function velocity_system:update_filter()
     for e in w:select "filter_result visible_state:in render_layer:in render_object:update filter_material:in name?in" do
        if e.visible_state["velocity_queue"] then
            local polylinelist
            if e.name and e.name == "polyline" then
                polylinelist = true
            end
            local mo = assert(which_material(polylinelist))
            local ro = e.render_object
            local fm = e.filter_material
            local mi = mo:instance()
            fm["velocity_queue"] = mi
            R.set(ro.rm_idx, queuemgr.material_index "velocity_queue", mi:ptr())
        end
    end 
end

function velocity_system:render_submit()
	local viewid = viewidmgr.get "velocity"
	bgfx.touch(viewid)
end

local vr_mb = world:sub{"view_rect_changed", "main_queue"}
local mc_mb = world:sub{"main_queue", "camera_changed"}
function velocity_system:data_changed()
     for _, _, vr in vr_mb:unpack() do
        local vme = w:first "velocity_queue render_target:in"
        fbmgr.resize_rb(fbmgr.get(vme.render_target.fb_idx)[1].rbidx, vr.w, vr.h)
        irq.set_view_rect("velocity_queue", vr)
    end

    for _, _, ceid in mc_mb:unpack() do
        local e = w:first "velocity_queue camera_ref:out"
        e.camera_ref = ceid
        w:submit(e)
    end 
end