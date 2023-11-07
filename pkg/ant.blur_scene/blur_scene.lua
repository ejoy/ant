local ecs   = ...
local world = ecs.world
local w     = world.w

local renderutil= ecs.require "ant.render|util"
local setting   = import_package "ant.settings"
local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local irender   = ecs.require "ant.render|render_system.render"
local ips       = ecs.require "ant.render|postprocess.pyramid_sample"
local iblur     = ecs.require "ant.render|postprocess.blur"
local ibs  = {}
local bs_sys = ecs.system "bs_system"

if not setting:get "graphic/postprocess/blur/enable" then
    renderutil.default_system(bs_sys, "entity_init, entity_remove, blur")
    return
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

local function create_blur_scene_entity(count)
    local max_count = count and count or 10
    world:create_entity {
        policy = {
            "ant.blur_scene|blur_scene",
        },
        data = {
            blur_scene = {
                cur_count = 0,
                max_count = max_count
            }
        },
    }
end

function bs_sys:entity_init()
    local bse = w:first "INIT blur_scene"
    if bse then
        create_stop_scene_entity()
        local tqe = w:first "tonemapping_queue render_target:in"
        local be  = w:first "blur pyramid_sample:update gaussian_blur:in"
        assert(be, "pyramid_sample should create before blur scene!\n")

        local input_handle = fbmgr.get_rb(tqe.render_target.fb_idx, 1).handle
        ips.do_pyramid_sample(be, input_handle) -- only do once
    end

    local sse = w:first "INIT stop_scene"
    if sse then
        irender.stop_draw(true)
    end
end

function bs_sys:entity_remove()
    local bse = w:first "REMOVED blur_scene"
    if bse then
        irender.stop_draw(false)

        local sse = w:first "stop_scene eid:in"
        if sse then
            w:remove(sse.eid)
        end
    end
end

function bs_sys:blur()
    local bse = w:first "blur_scene:in"
    if bse then
        local cur_count, max_count = bse.blur_scene.cur_count, bse.blur_scene.max_count
        if cur_count < max_count then
            cur_count = cur_count + 1
            local be  = w:first "blur pyramid_sample:update gaussian_blur:in"
            iblur.do_gaussian_blur(be)
            bse.blur_scene.cur_count = cur_count
        end        
    end  
end

function ibs.blur_scene(count)
    local bse = w:first "blur_scene"
    if not bse then
        create_blur_scene_entity(count)
    end
end

function ibs.restore_scene()
    local bse = w:first "blur_scene eid:in"
    if bse then
        w:remove(bse.eid)
    end
end

return ibs
