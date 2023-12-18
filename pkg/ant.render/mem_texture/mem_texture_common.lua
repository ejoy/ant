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
local queuemgr  = ecs.require "ant.render|queue_mgr"
local R         = world:clibs "render.render_material"
local hwi       = import_package "ant.hwi"
local mc        = import_package "ant.math".constant

local params = {
    WAIT_QUEUE = {},
    PREFABS = {},
    HANDLE_CACHE = {},
    VIEWID = hwi.viewid_get "mem_texture",
    QUEUE_NAME = "mem_texture_queue",
    DEFAULT_RT_WIDTH         = 512,
    DEFAULT_RT_HEIGHT        = 512,
    RB_FLAGS  = sampler{
        MIN =   "LINEAR",
        MAG =   "LINEAR",
        U   =   "CLAMP",
        V   =   "CLAMP",
        RT  =   "RT_ON",
    },
    DEFAULT_FB = {},
    DEFAULT_EXTENTS         = math3d.mark(math3d.vector(50, 50, 50)),
    DEFAULT_LENGTH          = math3d.length(math3d.mul(1.8, math3d.vector(50, 50, 50))),
    DEFAULT_SIZE_CONFIGS    = {
        {
            width  = 512,
            height = 512,
        },
        {
            width  = 256,
            height = 256,
        },
        {
            width  = 128,
            height = 128,
        },	
    },
    DEFAULT_ROT_CONFIGS     = {
        {0.785, 0, 0},
        {0.785, -0.785, 0},
        {0.785, 0.785, 0},
        {1.000, 0, 0},
        {1.000, 0.785, 0},
    } 
}

local m = {params = params}

local function add_wait_queue(name)
    params.WAIT_QUEUE[#params.WAIT_QUEUE+1] = name
end

local function parse_config(config)
    local portrait_tag, size_tag, rot_tag, dis = config:match "%w+:(%a),(%d),(%d),?([%d%.]*)"
    size_tag, rot_tag, dis = tonumber(size_tag), tonumber(rot_tag), tonumber(dis)
    local type = portrait_tag == 'd' and "dynamic" or "static"
    if type:match "dynamic" then
        rot_tag = 4
    end
    local size, rot
    size = size_tag and params.DEFAULT_SIZE_CONFIGS[size_tag] or params.DEFAULT_SIZE_CONFIGS[1]
    dis = dis and dis or 1.0
    rot = rot_tag and params.DEFAULT_ROT_CONFIGS[rot_tag] or params.DEFAULT_ROT_CONFIGS[1]
    return type, size, rot, dis
end

local function destroy_prefab_cache(handle, destroy_rb)
    local function destroy_prefab(objects)
        for _, eid in ipairs(objects) do
           w:remove(eid) 
        end
    end
    
    local name = params.HANDLE_CACHE[handle]
    local prefab = params.PREFABS[name]
    if not prefab then return end
    local objects, fb, camera_srt, prefab_rotation = prefab.objects, prefab.fb, prefab.camera_srt, prefab.prefab_rotaton
    if objects then
        destroy_prefab(objects)
    end
    if camera_srt and camera_srt.r and camera_srt.t then
        math3d.unmark(camera_srt.r)
        math3d.unmark(camera_srt.t) 
    end
    if fb and fb[1] and fb[2] and destroy_rb then
        fbmgr.destroy_rb(fb[1].rbidx, true)
        fbmgr.destroy_rb(fb[2].rbidx, true) 
    end
    params.PREFABS[name] = {}
end

function m.clear_prefab_cache()
    fbmgr.destroy_rb(params.DEFAULT_FB[1].rbidx, true)
    fbmgr.destroy_rb(params.DEFAULT_FB[2].rbidx, true)
    for handle, _ in pairs(params.HANDLE_CACHE) do
        destroy_prefab_cache(handle)
        params.HANDLE_CACHE[handle] = nil
    end
end

function m.add_wait_queue(name, prefab_rotation)
    if not params.PREFABS[name] then
        return
    end
    add_wait_queue(name)
    params.PREFABS[name].prefab_rotation = prefab_rotation
end

function m.destroy_portrait_prefab(handle)
    destroy_prefab_cache(handle, true)
    params.HANDLE_CACHE[handle] = nil
end

function m.parse_prefab_config(config)
    return parse_config(config)
end

function m.parse_prefab_name(name)
    local _, path, config = name:match "(%w+):(.*)%s(.*)"
    return path, parse_config(config)
end

function m.register_new_rt()

    local function register_mem_texture_render_queue(queue_name)
        w:register{name = queue_name}
    end
    
    local function register_mem_texture_material_queue(queue_name)
        local mem_texture_material_idx = queuemgr.material_index("main_queue")
        queuemgr.register_queue(queue_name, mem_texture_material_idx)
    end

    local function create_mem_texture_queue(view_id, queue_name)

        local fb = {
            {rbidx = fbmgr.create_rb{w = params.DEFAULT_RT_WIDTH, h = params.DEFAULT_RT_HEIGHT, layers = 1, format = "RGBA8", flags = params.RB_FLAGS}},
            {rbidx = fbmgr.create_rb{w = params.DEFAULT_RT_WIDTH, h = params.DEFAULT_RT_HEIGHT, layers = 1, format = "D16",   flags = params.RB_FLAGS}}
        }
    
        params.DEFAULT_FB = fb

        local fbidx = fbmgr.create(fb[1], fb[2])
    
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

    local queue_name, view_id = params.QUEUE_NAME, params.VIEWID
    register_mem_texture_render_queue(queue_name)
    register_mem_texture_material_queue(queue_name)
    create_mem_texture_queue(view_id, queue_name)
end

function m.create_prefab_entity(name, path, rotation, distance, type)

    local function set_prefab_params()
        local prefab = params.PREFABS[name]
        prefab.rotation, prefab.distance, prefab.type = rotation, distance, type
    end

    world:create_instance {
        prefab = path,
        on_ready = function (inst)
            local alleid = inst.tag['*']
            params.PREFABS[name].objects = alleid
            for _, eid in ipairs(alleid) do
                local ee <close> = world:entity(eid, "visible_state?in mesh?in scene?in mem_texture_ready?out")
                if ee.mesh and ee.visible_state then
                    ee.mem_texture_ready = true
                    ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                end
            end
        end
    }
    set_prefab_params()
end

function m.get_portrait_handle(name, width, height)
    local fb = {
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "RGBA8", flags = params.RB_FLAGS, unmark = true}},
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "D16",   flags = params.RB_FLAGS, unmark = true}}
    }
    params.PREFABS[name] = {fb = fb}
    local portrait_handle = fbmgr.get_rb(fb[1].rbidx).handle
    params.HANDLE_CACHE[portrait_handle] = name
    return portrait_handle
end

function m.get_camera_srt()

    local function calc_srt(camera_rot, aabb, distance)
        if not math3d.aabb_isvalid(aabb) then return end
        local origin_world_center, world_extents = math3d.aabb_center_extents(aabb)
        local view_dir = math3d.todirection(camera_rot)
        local view_len = params.DEFAULT_LENGTH * distance
        local camera_pos = math3d.sub(math3d.vector(0, 0, 0), math3d.mul(view_dir, view_len))
        local ex, ey, ez = math3d.index(world_extents, 1, 2, 3)
        local emax = math.max(ex, math.max(ey, ez))
        local scale_factor = math3d.vector(emax, emax, emax)
        scale_factor = math3d.reciprocal(scale_factor)
        scale_factor = math3d.mul(params.DEFAULT_EXTENTS, scale_factor)
        aabb = math3d.aabb_transform(math3d.matrix{s = scale_factor}, aabb)
        local world_center, _ = math3d.aabb_center_extents(aabb)
        local translation_offset = math3d.sub(world_center, origin_world_center)
        translation_offset = math3d.mul(-1, translation_offset)
        return camera_pos, scale_factor, translation_offset
    end

    local queue_name = params.QUEUE_NAME
    for name, prefab in pairs(params.PREFABS) do
        local objects, camera_srt, rotation, distance = prefab.objects, prefab.camera_srt, prefab.rotation, prefab.distance
        if (not camera_srt) and objects then
            local scene_aabb = math3d.aabb()
            local is_valid = false
            for _, eid in ipairs(objects) do
                local e = world:entity(eid, "bounding?in mem_texture_ready?update")
                if e.bounding and e.bounding.scene_aabb ~= mc.NULL and math3d.aabb_isvalid(e.bounding.scene_aabb) then
                    scene_aabb = math3d.aabb_merge(scene_aabb, e.bounding.scene_aabb)
                    is_valid = true
                    e.mem_texture_ready = false
                end
            end
            if is_valid then
                for _, eid in ipairs(objects) do
                    local e <close> = world:entity(eid, "scene?update")
                    if e.scene and e.scene.parent == 0  then
                        local select_tag = ("%s camera_ref:in"):format(queue_name)
                        local mtq = w:first(select_tag)
                        local camera<close> = world:entity(mtq.camera_ref, "scene:update camera:in")
                        local camera_rot = math3d.quaternion(rotation)
                        local camera_pos, scale_factor, translation_offset = calc_srt(camera_rot, scene_aabb, distance)
                        prefab.camera_srt = {r = math3d.mark(camera_rot), t = math3d.mark(camera_pos)}
                        local s, t = math3d.mul(scale_factor, e.scene.s), math3d.add(translation_offset, e.scene.t)
                        t = math3d.sub(t, math3d.vector(0, 10, 0))
                        iom.set_srt(e, s, e.scene.r, t)
                        add_wait_queue(name)
                        break
                    end
                end
            end
        end
    end
end

function m.copy_main_material()
    local queue_name = params.QUEUE_NAME
    for _, prefab in pairs(params.PREFABS) do
        if prefab.objects then
            for _, eid in ipairs(prefab.objects) do
                local e = world:entity(eid, "filter_result visible_state?in render_object?in filter_material?in")
                if e.filter_material and e.render_object then
                    local fm = e.filter_material
                    local mi = fm["main_queue"]
                    fm[queue_name] = mi
                    R.set(e.render_object.rm_idx, queuemgr.material_index(queue_name), mi:ptr()) 
                end
            end 
        end
    end
end

function m.process_wait_queue()

    local function update_fb(new_fb)
        if new_fb then
            local viewid = params.VIEWID
            local fbidx = fbmgr.get_fb_idx(viewid)
            fbmgr.recreate(fbidx, new_fb)
            local select_tag = ("%s render_target:update"):format(params.QUEUE_NAME)
            local mtq = w:first(select_tag)
            irq.update_rendertarget(params.QUEUE_NAME, mtq.render_target) 
        end
    end

    local function set_camera_srt(camera_srt)
        if camera_srt then
            local select_tag = ("%s camera_ref:in"):format(params.QUEUE_NAME)
            local mtq = w:first(select_tag)
            local camera<close> = world:entity(mtq.camera_ref, "scene:update camera:in")
            iom.set_position(camera, camera_srt.t)
            iom.set_rotation(camera, camera_srt.r) 
        end
    end

    local function set_objects_visible_state(prefab, state)
        if prefab and prefab.objects then
            for _, eid in ipairs(prefab.objects) do
                local ee <close> = world:entity(eid, "visible_state?in mesh?in")
                if ee.mesh and ee.visible_state then
                    ivs.set_state(ee, params.QUEUE_NAME, state)
                end
            end
        end
    end
    
    local function adjust_prefab_rot(prefab)
        local objects, prefab_rotation = prefab.objects, prefab.prefab_rotation
        if objects and prefab_rotation then
            for _, eid in ipairs(objects) do
                local e <close> = world:entity(eid, "scene?in")
                if e.scene and e.scene.parent == 0 then
                    iom.set_rotation(e, math3d.quaternion(prefab_rotation))
                end
            end 
        end
    end

    local last_name = params.LAST_PREFAB
    local last_prefab = params.PREFABS[last_name]
    set_objects_visible_state(last_prefab, false)

    local wait_queue = params.WAIT_QUEUE
    if #wait_queue >= 1 then
        local cur_name = wait_queue[1]
        table.remove(wait_queue, 1)
        local cur_prefab = params.PREFABS[cur_name]
        local fb, camera_srt = cur_prefab.fb, cur_prefab.camera_srt
        update_fb(fb)
        set_camera_srt(camera_srt)
        set_objects_visible_state(cur_prefab, true)
        adjust_prefab_rot(cur_prefab)
        params.LAST_PREFAB = cur_name
    elseif last_name then
        update_fb(params.DEFAULT_FB)
        params.LAST_PREFAB = nil
    end
end

return m
