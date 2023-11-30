local ecs   = ...
local world = ecs.world
local w     = world.w

local setting   = import_package "ant.settings"
local bs_sys = ecs.system "bs_system"
if not setting:get "graphic/postprocess/blur/enable" then
    return
end

local ENABLE_FXAA<const>    = setting:get "graphic/postprocess/fxaa/enable"
local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local irender   = ecs.require "ant.render|render_system.render"
local imaterial = ecs.require "ant.asset|material"
local ips       = ecs.require "ant.render|postprocess.pyramid_sample"
local ibs  = {}

local function create_stop_scene_entity()
    return world:create_entity {
        policy = {
            "ant.render|stop_scene"
        },
        data = {
            stop_scene = true
        },
    }
end

local function create_blend_scene_entity(material)
    local be  = w:first "blur pyramid_sample:in"
    local queue = be.pyramid_sample.upsample_queue .. ips.get_pyramid_mipcount()
    return world:create_entity {
        policy = {
            "ant.render|blend_scene",
            "ant.render|simplerender"
        },
        data = {
            blend_scene      = true,
            simplemesh       = irender.full_quad(),
            material         = material,
            visible_state    = queue,
            scene            = {},
            on_ready = function(e)
                imaterial.set_property(e, "s_scene_color", be.pyramid_sample.input_handle)
            end
        },
    }
end

local function create_blur_scene_entity(count)
    local max_count = count and count or 5
    world:create_entity {
        policy = {
            "ant.render|blur_scene",
        },
        data = {
            blur_scene = {
                cur_count = 0,
                max_count = 5,
                material  = "/pkg/ant.resources/materials/blend_scene.material"
            }
        },
    }
end


function bs_sys:entity_init()
    local bdse = w:first "INIT blend_scene"
    if bdse then
        create_stop_scene_entity()
    end

    local sse = w:first "INIT stop_scene"
    if sse then
        irender.stop_draw(true)
    end
end

function bs_sys:blur()

    local function get_input_handle()
        if ENABLE_FXAA then
            local fqe = w:first "fxaa_queue render_target:in"
            return fbmgr.get_rb(fqe.render_target.fb_idx, 1).handle
        else
            local tqe = w:first "tonemapping_queue render_target:in"
            return fbmgr.get_rb(tqe.render_target.fb_idx, 1).handle
        end
    end

    local bse = w:first "blur_scene:in"
    if bse then
        local input_handle
        bse.blur_scene.cur_count = bse.blur_scene.cur_count + 1
        if bse.blur_scene.cur_count < bse.blur_scene.max_count then
            --local be  = w:first "blur pyramid_sample:update gaussian_blur:in"
            local be  = w:first "blur pyramid_sample:update"
            if bse.blur_scene.cur_count == 1 then
                input_handle = get_input_handle()
                be.pyramid_sample.input_handle = input_handle
            else
                input_handle = be.pyramid_sample.scene_color_property.value
            end
            ips.do_pyramid_sample(be, input_handle)
        elseif bse.blur_scene.cur_count == bse.blur_scene.max_count then
            create_blend_scene_entity(bse.blur_scene.material)
        end
    end  
end

function ibs.blur_scene(count)
    local bse = w:first "blur_scene:in"
    if not bse then
        create_blur_scene_entity(count)
    end
end

function ibs.restore_scene()
    irender.stop_draw(false)
    local brse = w:first "blur_scene eid:in"
    local bdse = w:first "blend_scene eid:in"
    local sse  = w:first "stop_scene eid:in"
    if brse then
        w:remove(brse.eid)
    end
    if bdse then
        w:remove(bdse.eid)
    end
    if sse then
        w:remove(sse.eid)
    end    
end

return ibs
