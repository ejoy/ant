local ecs = ...
local world = ecs.world
local w = world.w
local mtd_sys = ecs.system "mem_texture_dynamic_system"
local ivs		= ecs.require "ant.render|visible_state"
local math3d    = require "math3d"
local ltask     = require "ltask"
local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler
local iom       = ecs.require "ant.objcontroller|obj_motion"
local icamera	= ecs.require "ant.camera|camera"
local irq		= ecs.require "ant.render|render_system.renderqueue"
local ig        = ecs.require "ant.group|group"
local R             = world:clibs "render.render_material"
local queuemgr      = ecs.require "ant.render|queue_mgr"
local hwi       = import_package "ant.hwi"
local itimer	= ecs.require "ant.timer|timer_system"
local mc = import_package "ant.math".constant

local lastname = "mem_texture_static"
local VIEWIDS = setmetatable({}, {
    __index = function(t,name)
        local viewid = hwi.viewid_get(name)
        if viewid then
            t[name] = viewid
        else
            t[name] = hwi.viewid_generate(name, lastname) 
        end
        return t[name] 
    end
})

local DYNAMIC_OBJ_NAME <const> =  "mem_texture_dynamic_obj"
local DYNAMIC_OBJS = {}
local DYNAMIC_QUEUE_NAME <const> = "mem_texture_dynamic_queue"
local DYNAMIC_QUEUES = {}
local ACTIVE_MASKS = {}

local DEFAULT_RT_WIDTH, DEFAULT_RT_HEIGHT <const> = 512, 512
local RB_FLAGS <const> = sampler{
    MIN =   "LINEAR",
    MAG =   "LINEAR",
    U   =   "CLAMP",
    V   =   "CLAMP",
    RT  =   "RT_ON",
}
local DEFAULT_EXTENTS <const> = math3d.mark(math3d.vector(50, 50, 50))
local DEFAULT_LENGTH <const> = math3d.length(math3d.mul(1.6, DEFAULT_EXTENTS))
local DISTANCE = {}

local function exist_prefab(obj_name)
    local select_tag = ("%s"):format(obj_name)
    return w:first(select_tag)
end


local function remove_prefab(obj_name)
    local select_tag = ("%s eid:in"):format(obj_name)
    for e in w:select(select_tag) do
        w:remove(e.eid)
    end
end

local function update_current_rt_handle(queue_name)
    local select_tag = ("%s render_target:update"):format(queue_name)
    local mtq = w:first(select_tag)
    local fbidx = mtq.render_target.fb_idx
    local fb = fbmgr.get(fbidx)
    fbmgr.unmark_rb(fbidx, 1)
    fbmgr.unmark_rb(fbidx, 1)
    fb = {
        {rbidx = fbmgr.create_rb{w = DEFAULT_RT_WIDTH, h = DEFAULT_RT_HEIGHT, layers = 1, format = "RGBA8", flags = RB_FLAGS}},
        {rbidx = fbmgr.create_rb{w = DEFAULT_RT_WIDTH, h = DEFAULT_RT_HEIGHT, layers = 1, format = "D16",   flags = RB_FLAGS}}
    }
    fbmgr.recreate(fbidx, fb)
    irq.update_rendertarget(queue_name, mtq.render_target)
end

local function register_new_rt()
    local function register_mem_texture_group(obj_name)
        w:register{name = obj_name}
        local gid = ig.register(obj_name)
        ig.enable(gid, obj_name, true)
    end
    
    local function register_mem_texture_render_queue(queue_name)
        w:register{name = queue_name}
    end
    
    local function register_mem_texture_material_queue(queue_name)
        local mem_texture_material_idx = queuemgr.material_index("main_queue")
        queuemgr.register_queue(queue_name, mem_texture_material_idx)
    end

    local function create_mem_texture_queue(view_id, queue_name)

        local fbidx = fbmgr.create(
            {rbidx = fbmgr.create_rb{w = DEFAULT_RT_WIDTH, h = DEFAULT_RT_HEIGHT, layers = 1, format = "RGBA8", flags = RB_FLAGS}},
            {rbidx = fbmgr.create_rb{w = DEFAULT_RT_WIDTH, h = DEFAULT_RT_HEIGHT, layers = 1, format = "D16",   flags = RB_FLAGS}}
        )
    
        world:create_entity {
            policy = {
                "ant.render|render_queue",
            },
            data = {
                camera_ref = world:create_entity{
                    policy = {
                        "ant.camera|camera",
                        "ant.camera|exposure"
                    },
                    data = {
                        scene = {
                            r = {1.0, 0, 0},
                            t = {0, 80, -50, 0},
                            updir = {0.0, 1.0, 0.0}
                    },
                      camera = {
                        frustum = {
                            aspect = 0.95,
                            f = 1000,
                            fov = 45,
                            n = 1,
                        }
                      },
                      exposure = {
                        type          = "manual",
                        aperture      = 16.0,
                        shutter_speed = 0.008,
                        ISO           = 20
                      },
                    }
                },
                render_target = {
                    viewid		= view_id,
                    view_mode 	= "s",
                    clear_state = {
                        color = 0x00000000,
                        depth = 0.0,
                        clear = "CD",
                    },
                    view_rect	= {x = 0, y = 0, w = DEFAULT_RT_WIDTH, h = DEFAULT_RT_HEIGHT},
                    fb_idx		= fbidx,
                },
                [queue_name]         = true,
                queue_name			 = queue_name,
                visible = true,
            }
        }
    end

    local new_idx = #ACTIVE_MASKS + 1
    local obj_name, queue_name = DYNAMIC_OBJ_NAME .. new_idx, DYNAMIC_QUEUE_NAME .. new_idx
    local view_id = VIEWIDS[queue_name]
    DYNAMIC_OBJS[#DYNAMIC_OBJS+1] = obj_name
    DYNAMIC_QUEUES[#DYNAMIC_QUEUES+1] = queue_name
    ACTIVE_MASKS[#ACTIVE_MASKS+1] = false
    register_mem_texture_group(obj_name)
    register_mem_texture_render_queue(queue_name)
    register_mem_texture_material_queue(queue_name)
    create_mem_texture_queue(view_id, queue_name)
end

local function get_active_rt()
    for idx, is_active in ipairs(ACTIVE_MASKS) do
        if not is_active then
            return idx
        end
    end
    return 0
end

local function set_rt_active(idx, is_active)
    ACTIVE_MASKS[idx] = is_active
end

local function expand_active_rt()
    local queue_num = #ACTIVE_MASKS
    local active_size = 0
    for _, is_active in ipairs(ACTIVE_MASKS) do
        if is_active then
            active_size = active_size + 1
        end
    end
    if active_size > queue_num / 2 then
        local new_size = queue_num * 2 + 1
        for i = queue_num + 1, new_size do
            register_new_rt()
        end
    end
end

function mtd_sys:init()
    register_new_rt()
end

function mtd_sys:update_filter()

    local function update_filter_prefab(obj_name, queue_name)
        if exist_prefab(obj_name) then
            local select_tag = ("filter_result %s visible_state:in render_object:in filter_material:in"):format(obj_name)
            for e in w:select(select_tag) do
                if e.visible_state[queue_name] then
                    local fm = e.filter_material
                    local mi = fm["main_queue"]
                    fm[queue_name] = mi
                    R.set(e.render_object.rm_idx, queuemgr.material_index(queue_name), mi:ptr())
                end
            end
        end
    end
    for rt_idx, is_active in ipairs(ACTIVE_MASKS) do
        if is_active then
            local obj_name, queue_name = DYNAMIC_OBJS[rt_idx], DYNAMIC_QUEUES[rt_idx]
            update_filter_prefab(obj_name, queue_name)
        end
    end
end

function mtd_sys:entity_init()
    local function adjust_camera_pos(camera, aabb, obj_name)
        if not math3d.aabb_isvalid(aabb) then return end
        local _, world_extents = math3d.aabb_center_extents(aabb)
        local view_dir = math3d.todirection(camera.scene.r)
        local view_len = DEFAULT_LENGTH * DISTANCE[obj_name]
        local camera_pos = math3d.sub(math3d.vector(0, 0, 0), math3d.mul(view_dir, view_len))
        iom.set_position(camera, camera_pos)
        local ex, ey, ez = math3d.index(world_extents, 1, 2, 3)
        local emax = math.max(ex, math.max(ey, ez))
        local scale = math3d.vector(emax, emax, emax)
        scale = math3d.reciprocal(scale)
        scale = math3d.mul(DEFAULT_EXTENTS, scale)
        aabb = math3d.aabb_transform(math3d.matrix{s = scale}, aabb)
        local world_center, _ = math3d.aabb_center_extents(aabb)
        return scale, math3d.mul(-1, world_center)
    end

    local function adjust_prefab(obj_name, queue_name)
        if exist_prefab(obj_name) then
            local select_tag = ("%s bounding:in mem_texture_ready:update"):format(obj_name)
            local scene_aabb = math3d.aabb()
            local is_valid = false
            for e in w:select(select_tag) do
                if e.bounding.scene_aabb ~= mc.NULL and math3d.aabb_isvalid(e.bounding.scene_aabb) then
                    scene_aabb = math3d.aabb_merge(scene_aabb, e.bounding.scene_aabb)
                    is_valid = true
                    e.mem_texture_ready = false
                end
            end
            if is_valid then
                select_tag = ("%s scene:in"):format(obj_name)
                for e in w:select(select_tag) do
                    if e.scene and e.scene.parent == 0  then
                        select_tag = ("%s camera_ref:in"):format(queue_name)
                        local mtq = w:first(select_tag)
                        local camera<close> = world:entity(mtq.camera_ref, "scene:update camera:in")
                        local s, t = adjust_camera_pos(camera, scene_aabb, obj_name)
                        iom.set_position(e, math3d.add(t, e.scene.t))
                        iom.set_scale(e, math3d.mul(s, e.scene.s))
                    end
                end 
            end
        end
    end
    for rt_idx, is_active in ipairs(ACTIVE_MASKS) do
        if is_active then
            local obj_name, queue_name = DYNAMIC_OBJS[rt_idx], DYNAMIC_QUEUES[rt_idx]
            adjust_prefab(obj_name, queue_name)
        end
    end   
end

local timepassed = 0.0
local delta_radian = math.pi * 0.1

function mtd_sys:data_changed()
    timepassed = timepassed + itimer.delta()
    local cur_time = timepassed * 0.001
    local cur_radian = delta_radian * cur_time

    for rt_idx, is_active in ipairs(ACTIVE_MASKS) do
        if is_active then
            local obj_name = DYNAMIC_OBJS[rt_idx]
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

    local function create_mem_texture_prefab(obj_name ,queue_name)
        world:create_instance {
            prefab = prefab_path,
            group  = ig.groupid(obj_name),
            on_ready = function (inst)
                local alleid = inst.tag['*']
                for _, eid in ipairs(alleid) do
                    local ee <close> = world:entity(eid, "visible_state?in mesh?in scene?in mem_texture_ready?out")
                    if ee.mesh and ee.visible_state then
                        ee.mem_texture_ready = true
                        ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                        ivs.set_state(ee, queue_name, true)
                    end
--[[                     if ee.scene and ee.scene.parent == 0 then
                        iom.set_rotation(ee, math3d.quaternion(rotation))
                    end ]]
                end
            end
        }
        ig.enable_from_name(obj_name, "view_visible", true)
    end

    local function resize_framebuffer(fbidx)
        local fb = fbmgr.get(fbidx)
        local changed = false

        for _, attachment in ipairs(fb)do
            local rbidx = attachment.rbidx
            changed = fbmgr.resize_rb(rbidx, width, height)
        end
        
        if changed then
            fbmgr.recreate(fbidx, fb)
        end
    end

    local function adjust_camera_rotation(queue_name)
        local select_tag = ("%s camera_ref:in"):format(queue_name)
        local mtq = w:first(select_tag)
        local camera<close> = world:entity(mtq.camera_ref, "scene:update camera:in")
        iom.set_rotation(camera, math3d.quaternion(rotation))
    end

    local function get_current_rt_handle(queue_name)
        local select_tag = ("%s render_target:update"):format(queue_name)
        local mtq = w:first(select_tag)
        local fbidx = mtq.render_target.fb_idx
        resize_framebuffer(fbidx)
        irq.update_rendertarget(queue_name, mtq.render_target)
        return fbmgr.get_rb(fbidx, 1).handle
    end

    local rt_idx = get_active_rt()
    assert(rt_idx > 0, "active rt isn't enough!\n")
    set_rt_active(rt_idx, true)
    expand_active_rt()

    local obj_name, queue_name = DYNAMIC_OBJ_NAME .. rt_idx, DYNAMIC_QUEUE_NAME .. rt_idx
    DISTANCE[obj_name] = distance
    create_mem_texture_prefab(obj_name ,queue_name)
    adjust_camera_rotation(queue_name)
    return get_current_rt_handle(queue_name), rt_idx
end

function S.destroy_mem_texture_dynamic_prefab(rt_idx)
    local obj_name, queue_name = DYNAMIC_OBJ_NAME .. rt_idx, DYNAMIC_QUEUE_NAME .. rt_idx
    remove_prefab(obj_name)
    update_current_rt_handle(queue_name)
    set_rt_active(rt_idx, false)
end