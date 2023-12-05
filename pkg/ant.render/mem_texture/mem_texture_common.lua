local ecs       = ...
local world     = ecs.world
local w         = world.w
local ivs		= ecs.require "ant.render|visible_state"
local math3d    = require "math3d"
local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler
local iom       = ecs.require "ant.objcontroller|obj_motion"
local irq		= ecs.require "ant.render|render_system.renderqueue"
local ig        = ecs.require "ant.group|group"
local R         = world:clibs "render.render_material"
local queuemgr  = ecs.require "ant.render|queue_mgr"
local hwi       = import_package "ant.hwi"
local mc        = import_package "ant.math".constant

local lastname = "mem_texture"
local params = {
    VIEWID                   = hwi.viewid_get "mem_texture",
    OBJ_NAME                 = "mem_texture_obj",
    QUEUE_NAME               = "mem_texture_queue",
    VIEWIDS                  = setmetatable({}, {
        __index = function(t,name)
            local viewid = hwi.viewid_get(name)
            if viewid then
                t[name] = viewid
            else
                t[name] = hwi.viewid_generate(name, lastname) 
            end
            return t[name] 
        end
    }),
    OBJS                     = {},
    QUEUES                   = {},
    ACTIVE_MASKS             = {},
    DISTANCE                 = {},
    DEFAULT_RT_WIDTH         = 512,
    DEFAULT_RT_HEIGHT        = 512,
    RB_FLAGS  = sampler{
        MIN =   "LINEAR",
        MAG =   "LINEAR",
        U   =   "CLAMP",
        V   =   "CLAMP",
        RT  =   "RT_ON",
    },
    DEFAULT_EXTENTS         = math3d.mark(math3d.vector(50, 50, 50)),
    DEFAULT_LENGTH          = math3d.length(math3d.mul(1.6, math3d.vector(50, 50, 50)))
}

local function exist_prefab(obj_name)
    local select_tag = ("%s"):format(obj_name)
    return w:first(select_tag)
end

local m = {
    params = params,
    register_new_rt      = function(view_id, obj_name, queue_name)
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
                {rbidx = fbmgr.create_rb{w = params.DEFAULT_RT_WIDTH, h = params.DEFAULT_RT_HEIGHT, layers = 1, format = "RGBA8", flags = params.RB_FLAGS}},
                {rbidx = fbmgr.create_rb{w = params.DEFAULT_RT_WIDTH, h = params.DEFAULT_RT_HEIGHT, layers = 1, format = "D16",   flags = params.RB_FLAGS}}
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
                        view_rect	= {x = 0, y = 0, w = params.DEFAULT_RT_WIDTH, h = params.DEFAULT_RT_HEIGHT},
                        fb_idx		= fbidx,
                    },
                    [queue_name]         = true,
                    queue_name			 = queue_name,
                    visible = true,
                }
            }
        end
        register_mem_texture_group(obj_name)
        register_mem_texture_render_queue(queue_name)
        register_mem_texture_material_queue(queue_name)
        create_mem_texture_queue(view_id, queue_name)
    end,
    create_prefab        = function(prefab_path, width, height, rotation, distance, obj_name, queue_name, is_dynamic)

        local function create_mem_texture_prefab()
            world:create_instance {
                prefab = prefab_path,
                group  = ig.groupid(obj_name),
                on_ready = function (inst)
                    local alleid = inst.tag['*']
                    for _, eid in ipairs(alleid) do
                        local ee <close> = world:entity(eid, "visible_state?in mesh?in scene?in mem_texture_ready?out mem_texture_dynamic?out")
                        if ee.mesh and ee.visible_state then
                            ee.mem_texture_ready = true
                            ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                            ivs.set_state(ee, queue_name, true)
                        end
                        if is_dynamic then
                            ee.mem_texture_dynamic = true
                        end
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
    
        local function adjust_camera_rotation()
            local select_tag = ("%s camera_ref:in"):format(queue_name)
            local mtq = w:first(select_tag)
            local camera<close> = world:entity(mtq.camera_ref, "scene:update camera:in")
            iom.set_rotation(camera, math3d.quaternion(rotation))
        end
    
        local function set_view_distance()
            params.DISTANCE[obj_name] = distance
        end
    
        local function get_current_rt_handle()
            local select_tag = ("%s render_target:update"):format(queue_name)
            local mtq = w:first(select_tag)
            local fbidx = mtq.render_target.fb_idx
            resize_framebuffer(fbidx)
            irq.update_rendertarget(queue_name, mtq.render_target)
            return fbmgr.get_rb(fbidx, 1).handle
        end

        set_view_distance()
        create_mem_texture_prefab()
        adjust_camera_rotation()
        return get_current_rt_handle()
    end,
    adjust_camera_srt    = function(obj_name, queue_name)

        local function adjust_camera_pos(camera, aabb)
            if not math3d.aabb_isvalid(aabb) then return end
            local _, world_extents = math3d.aabb_center_extents(aabb)
            local view_dir = math3d.todirection(camera.scene.r)
            local view_len =params. DEFAULT_LENGTH * params.DISTANCE[obj_name]
            local camera_pos = math3d.sub(math3d.vector(0, 0, 0), math3d.mul(view_dir, view_len))
            iom.set_position(camera, camera_pos)
            local ex, ey, ez = math3d.index(world_extents, 1, 2, 3)
            local emax = math.max(ex, math.max(ey, ez))
            local scale = math3d.vector(emax, emax, emax)
            scale = math3d.reciprocal(scale)
            scale = math3d.mul(params.DEFAULT_EXTENTS, scale)
            aabb = math3d.aabb_transform(math3d.matrix{s = scale}, aabb)
            local world_center, _ = math3d.aabb_center_extents(aabb)
            return scale, math3d.mul(-1, world_center)
        end
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
                        local s, t = adjust_camera_pos(camera, scene_aabb)
                        iom.set_position(e, math3d.add(t, e.scene.t))
                        iom.set_scale(e, math3d.mul(s, e.scene.s))
                    end
                end
            end
        end
    end,
    copy_main_material   = function(obj_name, queue_name)
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
    end,
    recreate_framebuffer = function(queue_name)
        local select_tag = ("%s render_target:update"):format(queue_name)
        local mtq = w:first(select_tag)
        local fbidx = mtq.render_target.fb_idx
        fbmgr.unmark_rb(fbidx, 1)
        fbmgr.unmark_rb(fbidx, 1)
        local fb = {
            {rbidx = fbmgr.create_rb{w = params.DEFAULT_RT_WIDTH, h = params.DEFAULT_RT_HEIGHT, layers = 1, format = "RGBA8", flags = params.RB_FLAGS}},
            {rbidx = fbmgr.create_rb{w = params.DEFAULT_RT_WIDTH, h = params.DEFAULT_RT_HEIGHT, layers = 1, format = "D16",   flags = params.RB_FLAGS}}
        }
        fbmgr.recreate(fbidx, fb)
        irq.update_rendertarget(queue_name, mtq.render_target)
    end,
    adjust_prefab_rot    = function(obj_name, cur_radian)
        local select_tag = ("%s mem_texture_dynamic scene:in"):format(obj_name)
        for e in w:select(select_tag) do
            if e.scene.parent == 0 then
                local cur_rot = e.scene.r
                local prefab_radian = math3d.quat2euler(cur_rot)
                prefab_radian = math3d.set_index(prefab_radian, 2, cur_radian)
                iom.set_rotation(e, math3d.quaternion(prefab_radian)) 
            end
        end
    end
}

return m
