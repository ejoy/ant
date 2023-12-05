local ecs       = ...
local world     = ecs.world
local w         = world.w
local mt_sys   = ecs.system "mem_texture_system"
local ltask     = require "ltask"
local itimer	= ecs.require "ant.timer|timer_system"
local mtc       = ecs.require "ant.render|mem_texture.mem_texture_common"
local params    = mtc.params

local function remove_prefab(obj_name)
    local select_tag = ("%s eid:in"):format(obj_name)
    for e in w:select(select_tag) do
        w:remove(e.eid)
    end
end

local function register_new_rt()
    local new_idx = #params.ACTIVE_MASKS + 1
    local obj_name, queue_name = params.OBJ_NAME .. new_idx, params.QUEUE_NAME .. new_idx
    local view_id = params.VIEWIDS[queue_name]
    params.OBJS[#params.OBJS+1] = obj_name
    params.QUEUES[#params.QUEUES+1] = queue_name
    params.ACTIVE_MASKS[#params.ACTIVE_MASKS+1] = false
    mtc.register_new_rt(view_id, obj_name, queue_name)
end

local function get_active_rt()
    for idx, is_active in ipairs(params.ACTIVE_MASKS) do
        if not is_active then
            return idx
        end
    end
    return 0
end

local function set_rt_active(idx, is_active)
    params.ACTIVE_MASKS[idx] = is_active
end

local function expand_active_rt()
    local queue_num = #params.ACTIVE_MASKS
    local active_size = 0
    for _, is_active in ipairs(params.ACTIVE_MASKS) do
        if is_active then
            active_size = active_size + 1
        end
    end
    if active_size >= queue_num then
        register_new_rt()
    end
end

function mt_sys:init()
    register_new_rt()
end

function mt_sys:update_filter()
    for rt_idx, is_active in ipairs(params.ACTIVE_MASKS) do
        if is_active then
            local obj_name, queue_name = params.OBJS[rt_idx], params.QUEUES[rt_idx]
            mtc.copy_main_material(obj_name, queue_name)
        end
    end
end

function mt_sys:entity_init()
    for rt_idx, is_active in ipairs(params.ACTIVE_MASKS) do
        if is_active then
            local obj_name, queue_name = params.OBJS[rt_idx], params.QUEUES[rt_idx]
            mtc.adjust_camera_srt(obj_name, queue_name)
        end
    end   
end

local timepassed = 0.0
local delta_radian = math.pi * 0.1

function mt_sys:data_changed()
    timepassed = timepassed + itimer.delta()
    local cur_time = timepassed * 0.001
    local cur_radian = delta_radian * cur_time

    for rt_idx, is_active in ipairs(params.ACTIVE_MASKS) do
        if is_active then
            local obj_name = params.OBJS[rt_idx]
            mtc.adjust_prefab_rot(obj_name, cur_radian)
        end
    end
end

local S = ltask.dispatch()

function S.create_mem_texture_prefab(prefab_path, width, height, rotation, distance, is_dynamic)
    local rt_idx = get_active_rt()
    set_rt_active(rt_idx, true)
    expand_active_rt()
    local obj_name, queue_name = params.OBJ_NAME .. rt_idx, params.QUEUE_NAME .. rt_idx
    return mtc.create_prefab(prefab_path, width, height, rotation, distance, obj_name, queue_name, is_dynamic), rt_idx
end

function S.destroy_mem_texture_prefab(rt_idx)
    local obj_name, queue_name = params.OBJ_NAME .. rt_idx, params.QUEUE_NAME .. rt_idx
    remove_prefab(obj_name)
    mtc.recreate_framebuffer(queue_name)
    set_rt_active(rt_idx, false)
end