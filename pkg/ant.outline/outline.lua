local ecs = ...
local world = ecs.world
local w     = world.w
local outline_system = ecs.system "outline_system"
local math3d	= require "math3d"
local bgfx		= require "bgfx"
local assetmgr  = import_package "ant.asset"

local hwi       = import_package "ant.hwi"
local queuemgr  = ecs.require "queue_mgr"
local R         = world:clibs "render.render_material"
local RM        = ecs.require "ant.material|material"
local iviewport = ecs.require "ant.render|viewport.state"

local outline_material
local outline_skinning_material

local outline_material_idx

local DEFAULT_STENCIL<const> = bgfx.make_stencil{
    TEST =  "ALWAYS",
    FUNC_REF =  1,
    FUNC_RMASK = 255,
    OP_FAIL_S = "REPLACE",
    OP_FAIL_Z = "REPLACE",
    OP_PASS_Z =  "REPLACE"
}

function outline_system:end_filter()
    for e in w:select "outline_info:update" do
        if e.outline_info.outline_color then
            local outline_scale, outline_color = e.outline_info.outline_scale, e.outline_info.outline_color
            w:extend(e, "filter_material:in")
            local fm = e.filter_material
            fm["outline_queue"]["u_outlinescale"] = math3d.vector(outline_scale, 0, 0, 0)
            fm["outline_queue"]["u_outlinecolor"] = math3d.vector(outline_color)
            e.outline_info = {} 
        end
    end  
end

local function which_material(skinning)
    if skinning then
        return outline_skinning_material.object
    else
        return outline_material.object
    end
end

local outline_viewid<const> = hwi.viewid_get "outline"

local function create_outline_queue()
    local mq = w:first("main_queue render_target:in camera_ref:in")
    local vr = iviewport.viewrect
    world:create_entity{
        policy = {
            "ant.render|outline_queue",
            "ant.render|watch_screen_buffer",
        },
        data = {
            camera_ref = mq.camera_ref,
            outline_queue = true,
            render_target = {
                view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
                viewid = outline_viewid,
                fb_idx = mq.render_target.fb_idx,
                view_mode = "s",
                clear_state = {
                    clear = "",
                },
            },
            queue_name = "outline_queue",
            watch_screen_buffer = true,
            visible = true
        }
    } 
end

function outline_system:init()
    outline_material 			= assetmgr.resource "/pkg/ant.resources/materials/outline/scale.material"
    outline_skinning_material   = assetmgr.resource "/pkg/ant.resources/materials/outline/scale_skinning.material"
    outline_material_idx	    = queuemgr.alloc_material()
    queuemgr.register_queue("outline_queue", outline_material_idx)
end

function outline_system:init_world()
    create_outline_queue()
end

function outline_system:update_filter()
    for e in w:select "filter_result visible_state:in render_layer:in render_object:update filter_material:in skinning?in" do
        if e.visible_state["outline_queue"] then
            local mo = assert(which_material(e.skinning))
            local ro = e.render_object
            local fm = e.filter_material
            local mi = RM.create_instance(mo)
            fm["outline_queue"] = mi
            fm["main_queue"]:set_stencil(DEFAULT_STENCIL)
            R.set(ro.rm_idx, queuemgr.material_index "outline_queue", mi:ptr())
        end
    end
end

function outline_system:render_submit()
	bgfx.touch(outline_viewid)
end

local mc_mb = world:sub{"main_queue", "camera_changed"}
function outline_system:data_changed()
    for _, _, ceid in mc_mb:unpack() do
        local e = w:first "outline_queue camera_ref:out"
        e.camera_ref = ceid
        w:submit(e)
    end
end