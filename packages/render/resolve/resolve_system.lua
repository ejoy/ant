local ecs   = ...
local world = ecs.world
local w     = world.w

local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"
local sampler   = require "sampler"
local md_resolve_sys = ecs.system "msaa_depth_resolve_system"

local depth_flags = sampler {
    RT="RT_ON",
	MIN="POINT",
	MAG="POINT",
	U="CLAMP",
	V="CLAMP",
}

local icompute = ecs.import.interface "ant.render|icompute"
local resolve_viewid<const> = viewidmgr.get "resolve"

--TODO: need check
local is_msaa_depth = true

function md_resolve_sys:init()
    if is_msaa_depth then
        ecs.create_entity{
            policy = {
                "ant.render|compute_policy",
                "ant.general|name",
            },
            data = {
                name    = "depth_resolver",
                material= "/pkg/ant.resources/materials/msaa_depth_resolve.material",
                dispatch={
                    size= {0, 0, 0},
                },
                compute = true,
                depth_resolver = true,
                on_ready = function (e)
                    w:sync("dispatch:in", e)
                    local material = e.dispatch.material
                    local mobj = material:get_material()
                    mobj:set_attrib("s_depth", {
                        stage=1, access='w', mip=0,
                        handle=nil,
                    })
                end
            }
        }
    end
end

function md_resolve_sys.init_world()
    if is_msaa_depth then
        local mq = w:singleton("main_queue", "render_target:in")
        local mvr = mq.render_target.view_rect
        ecs.create_entity {
            policy = {
                "ant.render|postprocess_queue",
                "ant.render|watch_screen_buffer",
                "ant.general|name",
            },
            data = {
                queue_name = "depth_resolver_queue",
                render_target = {
                    fb_idx = fbmgr.create{
                        rbidx=fbmgr.create_rb{
                            w=mvr.w, h=mvr.h,
                            layers=1, format="D32F",
                            flags=depth_flags,
                        }
                    },
                    clear_state = {clear=""},
                    view_rect = {x=mvr.x, y=mvr.y, w=mvr.w, h=mvr.h, ratio=mvr.ratio},
                    view_mode = "",
                    viewid = resolve_viewid,
                },
                watch_screen_buffer = true,
                name = "depth_resolver_queue",
                depth_resolver_queue = true,
            }
        }

    end
end

function md_resolve_sys.render_preprocess()
    if is_msaa_depth then
        local mq = w:singleton("main_queue", "render_target:in")
        local msaa_db = fbmgr.get_depth(mq.render_target.fb_idx)

        local dq = w:singleton("depth_resolver_queue", "render_target:in")
        local db = fbmgr.get_depth(dq.render_target.fb_idx)
        
        local drawer = w:singleton("depth_resolver", "dispatch:in")
        local material = drawer.dispatch.material
        material.s_msaa_depth    = msaa_db.handle
        material.s_depth         = db.handle
        icompute.dispatch(resolve_viewid, drawer.dispatch)
    end
end