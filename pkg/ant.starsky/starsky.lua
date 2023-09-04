local ecs = ...
local world = ecs.world
local w     = world.w
local starsky_system = ecs.system "starsky_system"
local bgfx      = require "bgfx"
local layoutmgr = ecs.require "ant.render|vertexlayout_mgr"
local assetmgr  = import_package "ant.asset"


local function get_tex_ratio(vr, texinfo)
    local vw, vh = vr.w, vr.h
    local tw, th = texinfo.width, texinfo.height
    local rw, rh = vw / tw, vh / th
    local twb, thb = math.random(), math.random()
    local twe, the = twb + rw, thb + rh
    return twb, thb, twe, the
end

function starsky_system:component_init()
    for e in w:select "INIT starsky simplemesh:out" do
        local mq = w:first "main_queue render_target:in camera_ref:in"
        local vr = mq.render_target.view_rect
        local texinfo =  assetmgr.resource("/pkg/vaststars.resources/textures/sky/star_sky.texture").texinfo
        local twb, thb, twe, the = get_tex_ratio(vr, texinfo)
        e.simplemesh = {
            vb = {
                start = 0,
                num = 4,
                handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("ffff", {
                   -1.0, 1.0, twb, thb,
                    1.0, 1.0, twe, thb,
                   -1.0,-1.0, twb, the,
                    1.0,-1.0, twe, the,
                }), layoutmgr.get "p2|t2".handle),
                owned = true,
            }
        }
    end
end