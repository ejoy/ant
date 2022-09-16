local ecs   = ...
local world = ecs.world
local w     = world.w

local viewidmgr = require "viewid_mgr"

local tm_sys    = ecs.system "tonemapping_system"
local ientity   = ecs.import.interface "ant.render|ientity"
local irender   = ecs.import.interface "ant.render|irender"
local irq       = ecs.import.interface "ant.render|irenderqueue"
local util      = ecs.require "postprocess.util"

local setting   = import_package "ant.settings".setting
local enable_bloom = setting:get "graphic/postprocess/bloom/enable"

local tm_viewid<const> = viewidmgr.get "tonemapping"
local tm_materialfile<const> = "/pkg/ant.resources/materials/postprocess/tonemapping.material"

function tm_sys:init()
    util.create_quad_drawer("tonemapping_drawer", tm_materialfile)
end

function tm_sys:init_world()
    local vp = world.args.viewport
    local vr = {x=vp.x, y=vp.y, w=vp.w, h=vp.h}
    util.create_queue(tm_viewid, vr, nil, "tonemapping_queue", "tonemapping_queue")
end

local vp_changed_mb = world:sub{"world_viewport_changed"}

function tm_sys:data_changed()
    for _, vp in vp_changed_mb:unpack() do
        irq.set_view_rect("tonemapping_queue", vp)
        break
    end
end

local function update_properties(material)
    --TODO: we need something call frame graph, frame graph need two stage: compile and run, with virtual resource
    -- in compile stage, determine which postprocess stage is needed, and connect those virtual resources
    -- render target here, is one of the virtual resource
    local pp = w:first("postprocess postprocess_input:in")
    local ppi = pp.postprocess_input
    material.s_scene_color = assert(ppi.scene_color_handle)
    if enable_bloom then
        material.s_bloom_color = assert(ppi.bloom_color_handle)
    end
end

function tm_sys:tonemapping()
    local m = w:first("tonemapping_drawer filter_material:in")
    update_properties(m.filter_material.main_queue)
    irender.draw(tm_viewid, "tonemapping_drawer")
end