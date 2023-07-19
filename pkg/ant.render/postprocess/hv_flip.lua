local ecs   = ...
local world = ecs.world
local w     = world.w

local setting = import_package "ant.settings".setting

local ru = require "util"
local hvflip_sys = ecs.system "hv_flip_system"

local ENABLE_HV_FLIP<const> = setting:get "graphic/postprocess/hv_flip/enable"

if not ENABLE_HV_FLIP then
    ru.default_system(hvflip_sys, "init", "init_world", "flip")
    return
end

local bgfx      = require "bgfx"
local declmgr   = require "vertexdecl_mgr"
local viewidmgr = require "viewid_mgr"
local fbmgr     = require "framebuffer_mgr"

local util      = ecs.require "postprocess.util"

local imaterial = ecs.import.interface "ant.asset|imaterial"

local hvflip_viewid = viewidmgr.generate("hv_flip", "fxaa")

function hvflip_sys:init()
    ecs.create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.general|name",
        },
        data = {
            name = "hv_flip_drawer",
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
					}), declmgr.get "p2|t2".handle),
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
    local vp = world.args.viewport
    local vr = {x=vp.x, y=vp.y, w=vp.h, h=vp.w}

    util.create_queue(hvflip_viewid, vr, nil, "hv_flip_queue", "hv_flip_queue", false)
end

function hvflip_sys:flip()
    local tme = w:first "fxaa_queue render_target:in"
    local d = w:first "hv_flip_drawer filter_material:in"
    imaterial.set_property(d, "s_tex", fbmgr.get_rb(tme.render_target.fb_idx, 1).handle)
end