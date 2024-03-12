local ecs = ...
local world = ecs.world
local w     = world.w
local outline_system = ecs.system "outline_system"
local math3d	= require "math3d"
local bgfx		= require "bgfx"
local assetmgr  = import_package "ant.asset"

local hwi       = import_package "ant.hwi"
local queuemgr  = ecs.require "ant.render|queue_mgr"
local ivm       = ecs.require "ant.render|visible_mask"

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
            "ant.outline|outline_queue",
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

function outline_system:entity_ready()
    for e in w:select "filter_result outline_info:in render_object:in filter_material:in skinning?in" do
        assert(ivm.check(e, "outline_queue"))
        local mo = assert(which_material(e.skinning))
        local ro = e.render_object
        local fm = e.filter_material
        local mi = RM.create_instance(mo)
        local outline_midx = assert(queuemgr.material_index "outline_queue", "Invalid 'outline_queue'")
        fm[outline_midx] = mi

        local mq_midx = queuemgr.material_index "outline_queue"
        assert(fm[mq_midx]):set_stencil(DEFAULT_STENCIL)
        R.set(ro.rm_idx, outline_midx, mi:ptr())

        local oi = e.outline_info
        mi["u_outlinescale"] = math3d.vector(oi.outline_scale, 0, 0, 0)
        mi["u_outlinecolor"] = math3d.vector(oi.outline_color)
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

local ioutline = {}
local function tomi(e)
    local ol_idx = assert(queuemgr.material_index "outline_queue")
    return assert(e.filter_material[ol_idx], "entity outline material instance is not ready")
end
function ioutline.update_outline_color(e, color)
    w:extend(e, "outline_info:in filter_material:in")
    e.outline_info.outline_color = color

    local mi = tomi(e)
    mi["u_outline_color"] = color
end

function ioutline.update_outline_scale(e, scale)
    w:extend(e, "outline_info:in")
    e.outline_info.outline_scale = scale

    local mi = tomi(e)
    mi["u_outline_scale"] = math3d.vector(scale, 0, 0, 0)
end

return ioutline