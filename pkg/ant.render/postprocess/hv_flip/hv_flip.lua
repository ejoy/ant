local ecs   = ...
local world = ecs.world
local w     = world.w

local setting = import_package "ant.settings"
local hvflip_sys = ecs.system "hv_flip_system"
local ENABLE_HV_FLIP<const> = setting:get "graphic/postprocess/hv_flip/enable"
if not ENABLE_HV_FLIP then
    return
end

local hwi       = import_package "ant.hwi"
local mu        = import_package "ant.math".util

local bgfx      = require "bgfx"
local layoutmgr = require "vertexlayout_mgr"

local fbmgr     = require "framebuffer_mgr"

local util      = ecs.require "postprocess.util"

local imaterial = ecs.require "ant.asset|material"
local iviewport = ecs.require "ant.render|viewport.state"

local hvflip_viewid<const> = hwi.viewid_generate("hv_flip", "fxaa")

function hvflip_sys:init()
    world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            hv_flip_drawer = true,
            simplemesh = {
                vb = {
                    start = 0,
                    num = 4,
--[[
    v0---v1
    |     |
    v3---v2

    from:           to:
    u0v0--u1v0          u1v0-------u1v1
    |        |          |             |
    |        |          u0v0-------u1v0
    |        |
    u1v0--u1v1
]]
					handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("ffff", {
					   -1.0, 1.0, 1.0, 1.0,
						1.0, 1.0, 1.0, 0.0,
                       -1.0,-1.0, 0.0, 1.0,
						1.0,-1.0, 0.0, 0.0,
					}), layoutmgr.get "p2|t2".handle),
					owned = true,
                }
            },
            owned_mesh_buffer = true,
            material = "/pkg/ant.resources/materials/hv_flip.material",
            visible_state = "hv_flip_queue",
            scene = {}
        }
    }
end

function hvflip_sys:init_world()
    util.create_queue(hvflip_viewid, mu.copy_viewrect(iviewport.viewrect), nil, "hv_flip_queue", "hv_flip_queue", false)
end

function hvflip_sys:flip()
    local tme = w:first "fxaa_queue render_target:in"
    local d = w:first "hv_flip_drawer filter_material:in"
    imaterial.set_property(d, "s_tex", fbmgr.get_rb(tme.render_target.fb_idx, 1).handle)
end