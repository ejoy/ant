local ecs       = ...
local world     = ecs.world
local w         = world.w
local mtd_sys   = ecs.system "mem_texture_dynamic_system"
local math3d    = require "math3d"
local ltask     = require "ltask"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local itimer	= ecs.require "ant.timer|timer_system"
local mtc       = ecs.require "ant.render|mem_texture.mem_texture_common"
local params    = mtc.params

local function remove_prefab(obj_name)
    local select_tag = ("%s eid:in"):format(obj_name)
    for e in w:select(select_tag) do
        w:remove(e.eid)
    end
end

local function register_new_dynamic_rt()
    local new_idx = #params.ACTIVE_MASKS + 1
    local obj_name, queue_name = params.DYNAMIC_OBJ_NAME .. new_idx, params.DYNAMIC_QUEUE_NAME .. new_idx
    local view_id = params.MEM_TEXTURE_DYNAMIC_VIEWIDS[queue_name]
    params.DYNAMIC_OBJS[#params.DYNAMIC_OBJS+1] = obj_name
    params.DYNAMIC_QUEUES[#params.DYNAMIC_QUEUES+1] = queue_name
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
    if active_size > queue_num / 2 then
        local new_size = queue_num * 2 + 1
        for i = queue_num + 1, new_size do
            register_new_dynamic_rt()
        end
    end
end

function mtd_sys:init()
    register_new_dynamic_rt()
end

function mtd_sys:update_filter()
    for rt_idx, is_active in ipairs(params.ACTIVE_MASKS) do
        if is_active then
            local obj_name, queue_name = params.DYNAMIC_OBJS[rt_idx], params.DYNAMIC_QUEUES[rt_idx]
            mtc.copy_main_material(obj_name, queue_name)
        end
    end
end

function mtd_sys:entity_init()
    for rt_idx, is_active in ipairs(params.ACTIVE_MASKS) do
        if is_active then
            local obj_name, queue_name = params.DYNAMIC_OBJS[rt_idx], params.DYNAMIC_QUEUES[rt_idx]
            mtc.adjust_camera_srt(obj_name, queue_name)
        end
    end   
end

local timepassed = 0.0
local delta_radian = math.pi * 0.1

function mtd_sys:data_changed()
    timepassed = timepassed + itimer.delta()
    local cur_time = timepassed * 0.001
    local cur_radian = delta_radian * cur_time

    for rt_idx, is_active in ipairs(params.ACTIVE_MASKS) do
        if is_active then
            local obj_name = params.DYNAMIC_OBJS[rt_idx]
            local select_tag = ("%s scene:in"):format(obj_name)
            for e in w:select(select_tag) do
                if e.scene.parent == 0 then
                    local cur_rot = e.scene.r
                    local prefab_radian = math3d.quat2euler(cur_rot)
                    prefab_radian = math3d.set_index(prefab_radian, 2, cur_radian)
                    iom.set_rotation(e, math3d.quaternion(prefab_radian)) 
                end
            end
        end
    end
end

local S = ltask.dispatch()

function S.create_mem_texture_dynamic_prefab(prefab_path, width, height, rotation, distance)
    local rt_idx = get_active_rt()
    assert(rt_idx > 0, "active rt isn't enough!\n")
    set_rt_active(rt_idx, true)
    expand_active_rt()

    local obj_name, queue_name = params.DYNAMIC_OBJ_NAME .. rt_idx, params.DYNAMIC_QUEUE_NAME .. rt_idx

    return mtc.create_prefab(prefab_path, width, height, rotation, distance, obj_name, queue_name), rt_idx
end

function S.destroy_mem_texture_dynamic_prefab(rt_idx)
    local obj_name, queue_name = params.DYNAMIC_OBJ_NAME .. rt_idx, params.DYNAMIC_QUEUE_NAME .. rt_idx
    remove_prefab(obj_name)
    mtc.recreate_framebuffer(queue_name)
    set_rt_active(rt_idx, false)
end