local ecs       = ...
local world     = ecs.world
local w         = world.w
local fbmgr     = require "framebuffer_mgr"
local math3d    = require "math3d"
local setting   = import_package "ant.settings"
local imaterial = ecs.require "ant.render|material"
local util      = ecs.require "postprocess.util"
local pp_sys    = ecs.system "postprocess_system"

local mq_camera_mb = world:sub{"main_queue", "camera_changed"}

--------------------------------------------------------------------------------------------------------------

-- postprocess_object

-- () optional [] fixed
-- (bloom)                  input:  main                                 output:    bloom_last_upsample
-- [tonemapping]            input:  main, (bloom_last_upsample)          output:    tonemapping
-- (effect)                 input:  tonemapping                          output:    effect
-- [fxaa/taa]               input:  effect/tonemapping                   output:    fxaa/taa/present
-- (fsr)                    input:  fxaa/taa                             output:    present

--------------------------------------------------------------------------------------------------------------

local function check_switch(name)
    local stage = string.format("graphic/postprocess/%s/enable", name)
    return setting:get(stage)
end

local function get_frame_graph()
    local bloom, effect, fxaa, taa, fsr = check_switch "bloom", check_switch "effect", check_switch "fxaa", check_switch "taa", check_switch "fsr"
    return {
        ["main"]        = {},
        ["bloom"]       = bloom  and {input = "main"}                                               or nil,
        ["tonemapping"] = true   and {input = {"main", bloom and "bloom"}}                          or nil,
        ["effect"]      = effect and {input = "tonemapping"}                                        or nil,
        ["fxaa"]        = fxaa   and {input = effect and "effect" or "tonemapping"}                 or nil,
        ["taa"]         = taa    and {input = effect and "effect" or "tonemapping"}                 or nil,
        ["fsr"]         = fsr    and {input = fxaa and "fxaa" or (taa and "taa" or "tonemapping")}  or nil
    }
end

local frame_graph = get_frame_graph()

local ifg = {}

function ifg.get_stage_input(stage, idx)
    if idx then
        return frame_graph[stage].input[idx]
    else
        return frame_graph[stage].input
    end
end

function ifg.get_stage_output(stage)
    return frame_graph[stage].output
end

function ifg.set_stage_output(stage, handle)
    frame_graph[stage].output = handle
end

function ifg.get_last_output(stage, idx)
    local current_input_stage = ifg.get_stage_input(stage, idx)
    return ifg.get_stage_output(current_input_stage)
end


local need_update_scene_buffers

local need_update_pp_param
local function update_postprocess_param()
    for _, _, ceid in mq_camera_mb:unpack() do
        need_update_pp_param = ceid
    end

    if not need_update_pp_param then
        local mq = w:first "main_queue camera_ref:in"
        local ce = world:entity(mq.camera_ref, "camera_changed?in")
        if ce.camera_changed then
            need_update_pp_param = mq.camera_ref
        end
    end

    if need_update_pp_param then
        local ce = world:entity(need_update_pp_param, "camera:in")
        local projmat = ce.camera.projmat
        local X, Y, A, B = util.reverse_position_param(projmat)
        imaterial.system_attrib_update("u_reverse_pos_param", math3d.vector(X, Y, A, B))
        need_update_pp_param = nil
    end
end

function pp_sys:init_world()
    local mq = w:first("main_queue camera_ref:in")
    need_update_pp_param = mq.camera_ref
    need_update_scene_buffers = true
end

local viewrect_changed = world:sub{"view_rect_changed", "main_queue"}

local function update_frame_graph()
    for _ in viewrect_changed:each() do
        need_update_scene_buffers = true
    end
    if need_update_scene_buffers then
        local mq = w:first "main_queue render_target:in camera_ref:in"
        local fb = fbmgr.get(mq.render_target.fb_idx)
        local handle = fb[1].handle
        ifg.set_stage_output("main", handle)
        need_update_scene_buffers = nil
    end
end

function pp_sys:pre_postprocess()
    update_postprocess_param()
    update_frame_graph()
end

return ifg