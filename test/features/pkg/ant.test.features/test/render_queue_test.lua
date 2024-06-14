local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"

local util		= ecs.require "util"

local PC		= util.proxy_creator()
local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler

local hwi       = import_package "ant.hwi"
local assetmgr  = import_package "ant.asset"
local mu        = import_package "ant.math".util

local queuemgr  = ecs.require "ant.render|queue_mgr"
local irender   = ecs.require "ant.render|render"
local iviewport = ecs.require "ant.render|viewport.state"
local imaterial = ecs.require "ant.render|material"
local icamera   = ecs.require "ant.camera|camera"
local ientity   = ecs.require "ant.entity|entity"

local common 	= ecs.require "common"

local rq_sys_test = common.test_system "render_queue"

local function create_fb(vr)
    return fbmgr.create{
        rbidx = fbmgr.create_rb{
            w = vr.w, h = vr.h, layers = 1,
            format = "RGBA8",
            flags = sampler{
                U = "CLAMP",
                V = "CLAMP",
                MIN="LINEAR",
                MAG="LINEAR",
                RT="RT_ON",
                BLIT="BLIT_COMPUTEWRITE"
            },
        }
    }
end

local TEST_QUEUENAME<const> = "render_queue_test"

local rq_viewid<const> = hwi.viewid_generate(TEST_QUEUENAME, "pre_depth")

local RENDER_ARG

local function register_queue(vr, cameraeid)
    queuemgr.register_queue(TEST_QUEUENAME)
    RENDER_ARG = irender.pack_render_arg(TEST_QUEUENAME, rq_viewid)

    return PC:create_entity{
        policy = {
            "ant.render|render_queue",
        },
        data = {
            camera_ref = cameraeid,
            render_target = {
                viewid = rq_viewid,
                view_rect = vr,
                clear_state = {
                    clear = "CD",   --clear color and depth
                    color = 0,
                    depth = 0,
                },
                fb_idx = create_fb(vr),
            },
            --submit_queue = true,  -- if we want to render objects that hung on this queue every frame
            queue_name = TEST_QUEUENAME,
            visible = true,
        }
    }
end

local function rect2d_to_rectndc(rect2d, vr)
    local x, y = rect2d.x / vr.w, rect2d.y / vr.h
    local ww, hh = rect2d.w / vr.w, rect2d.h / vr.h

    x, y = x*2.0-1.0, 1.0-(y*2.0-1.0)
    return {x=x, y=y, w=ww, h=hh}
end

function rq_sys_test:init()
    local ceid = icamera.create{
        viewdir = math3d.vector(0.0, 0.0, 1.0, 0.0),
        eyepos = math3d.vector(0.0, 0.0, -1.0, 1.0),
    }
    PC:add_entity(ceid)
    local testqueue_vr = {x=0, y=0, w=128, h=128}
    local qied = register_queue(testqueue_vr, ceid)

    --quad in render_queue_test
    local whitetex = assetmgr.resource "/pkg/ant.resources/textures/white.texture"
    local objeid = PC:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            mesh_result = ientity.fullquad_mesh(),
            material    = "/pkg/ant.resources/materials/texquad.material",
            visible_masks = TEST_QUEUENAME,
            visible     = true,
            scene       = {},
            on_ready = function (e)
                imaterial.set_property(e, "s_tex", whitetex.id)
                imaterial.set_property(e, "u_color", math3d.vector(1.5, 0.1, 0.3, 1.0))
            end
        }
    }

    --quad in main_view
    PC:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            mesh_result = ientity.create_mesh{"p3|t2", {
                0.0, 0.0, 0.0, 0.0, 1.0,
                0.0, 1.0, 0.0, 0.0, 0.0, 
                1.0, 0.0, 0.0, 1.0, 1.0,
                1.0, 1.0, 0.0, 1.0, 0.0,
            }},
            material    = "/pkg/ant.resources/materials/texquad.material",
            visible_masks = "main_view",
            visible     = true,
            scene       = {},
            render_layer = "translucent",
            on_ready    = function (e)
                irender.draw(RENDER_ARG, objeid)

                local rqt = world:entity(qied, "render_target:in")
                local hcolor = fbmgr.get_rb(rqt.render_target.fb_idx, 1).handle
                imaterial.set_property(e, "s_tex", hcolor)
            end
        }
    }

end

