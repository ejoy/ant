local ecs   = ...
local world = ecs.world
local w     = world.w

local renderutil= ecs.require "ant.render|util"
local setting   = import_package "ant.settings"
local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local irender   = ecs.require "ant.render|render_system.render"
local ips       = ecs.require "ant.render|postprocess.pyramid_sample"
local ibs  = {}
local bs_sys = ecs.system "bs_system"

if not setting:get "graphic/postprocess/blur/enable" then
    renderutil.default_system(bs_sys, "entity_init, entity_remove")
    return
end

local function create_blur_scene_entity()
    return world:create_entity {
        policy = {
            "ant.blur_scene|blur_scene",
        },
        data = {
            blur_scene = {}
        },
    }
end

local function create_stop_scene_entity()
    return world:create_entity {
        policy = {
            "ant.blur_scene|stop_scene",
        },
        data = {
            stop_scene = true
        },
    }
end

function bs_sys:entity_init()
    local bse = w:first "INIT blur_scene:update stop_scene?out"
    if bse then
        local tqe = w:first "tonemapping_queue render_target:in"
        local be  = w:first "blur pyramid_sample:update"
        local input_handle = fbmgr.get_rb(tqe.render_target.fb_idx, 1).handle
        ips.do_pyramid_sample(be, input_handle)
        bse.blur_scene.stop_scene_eid = create_stop_scene_entity()
        ips.set_pyramid_visible(be, true)
    end

    local sse = w:first "INIT stop_scene"
    if sse then
        irender.stop_draw(true)
    end
end

function bs_sys:entity_remove()
    for bse in w:select "REMOVED blur_scene:in" do
        local be  = w:first "blur pyramid_sample:update"
        ips.set_pyramid_visible(be, false)
        irender.stop_draw(false)
        w:remove(bse.blur_scene.stop_scene_eid)
    end
end

function ibs.blur_scene()
    local be = w:first "blur pyramid_sample:in"
    if be then
        local bse = create_blur_scene_entity()
        local output_handle = be.pyramid_sample.scene_color_property.value
        return bse, output_handle
    end
end

return ibs
