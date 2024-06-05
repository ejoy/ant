local ecs = ...
local world = ecs.world
local w     = world.w
local starsky_system = ecs.system "starsky_system"
local bgfx      = require "bgfx"
local layoutmgr = ecs.require "ant.render|vertexlayout_mgr"
local assetmgr  = import_package "ant.asset"
local ientity   = ecs.require "ant.entity|entity"

local function get_tex_ratio(vr, texinfo)
    local vw, vh = vr.w, vr.h
    local tw, th = texinfo.width, texinfo.height
    local rw, rh = vw / tw, vh / th
    local twb, thb = math.random(), math.random()
    local twe, the = twb + rw, thb + rh
    return twb, thb, twe, the
end

function starsky_system:component_init()
    for e in w:select "INIT starsky mesh_result:out owned_mesh_buffer:out" do
        local mq = w:first "main_queue render_target:in camera_ref:in"
        local vr = mq.render_target.view_rect
        local texinfo =  assetmgr.resource("/pkg/vaststars.resources/textures/sky/star_sky.texture").texinfo
        local twb, thb, twe, the = get_tex_ratio(vr, texinfo)
        e.mesh_result = ientity.create_mesh{
                "p2|t2", {
                -1.0, 1.0, twb, thb,
                1.0, 1.0, twe, thb,
                -1.0,-1.0, twb, the,
                1.0,-1.0, twe, the,
            }
        }
        e.owned_mesh_buffer = true
    end
end