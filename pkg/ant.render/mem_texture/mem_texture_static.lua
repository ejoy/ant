local ecs = ...
local world = ecs.world
local w = world.w
local mts_sys = ecs.system "mem_texture_static_system"
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
local mc = import_package "ant.math".constant

local MEM_TEXTURE_STATIC_VIEWID <const> = hwi.viewid_get "mem_texture_static"
local STATIC_OBJ_NAME <const> =  "mem_texture_static_obj"
local STATIC_QUEUE_NAME <const> = "mem_texture_static_queue"
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

local function register_mem_texture_group()
    w:register{name = STATIC_OBJ_NAME}
    local gid = ig.register(STATIC_OBJ_NAME)
    ig.enable(gid, STATIC_OBJ_NAME, true)
end

local function register_mem_texture_render_queue()
    w:register{name = STATIC_QUEUE_NAME}
end

local function register_mem_texture_material_queue()
    local mem_texture_material_idx = queuemgr.material_index("main_queue")
    queuemgr.register_queue(STATIC_QUEUE_NAME, mem_texture_material_idx)
end

local function create_mem_texture_queue(view_id, queue_name)

    local fbidx = fbmgr.create(
        {rbidx = fbmgr.create_rb{w = DEFAULT_RT_WIDTH, h = DEFAULT_RT_HEIGHT, layers = 1, format = "RGBA8", flags = RB_FLAGS}},
        {rbidx = fbmgr.create_rb{w = DEFAULT_RT_WIDTH, h = DEFAULT_RT_HEIGHT, layers = 1, format = "D16",   flags = RB_FLAGS}}
    )

    local mq = w:first("main_queue render_target:in")
    local mqvr = mq.render_target.view_rect

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
                        r = {0.785, 0.785, 0},
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
				view_rect	= {x = 0, y = 0, w = mqvr.w, h = mqvr.h},
				fb_idx		= fbidx,
			},
            [queue_name]         = true,
			queue_name			 = queue_name,
            visible = true,
		}
	}
end

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

local function create_clear_static_prefab_entity()
    remove_prefab(STATIC_OBJ_NAME)
    world:create_entity {
        policy = {
            "ant.render|clear_smt_prefab"
        },
        data = {
            clear_smt_prefab = true
        },
    }
end

function mts_sys:init()
    register_mem_texture_group()
    register_mem_texture_render_queue()
    register_mem_texture_material_queue()
end

function mts_sys:init_world()
    create_mem_texture_queue(MEM_TEXTURE_STATIC_VIEWID, STATIC_QUEUE_NAME)
end

function mts_sys:update_filter()

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

    update_filter_prefab(STATIC_OBJ_NAME, STATIC_QUEUE_NAME)
end

function mts_sys:entity_init()
    local function adjust_camera_pos(camera, aabb)
        if not math3d.aabb_isvalid(aabb) then return end
        local _, world_extents = math3d.aabb_center_extents(aabb)
        local view_dir = math3d.todirection(camera.scene.r)
        local view_len = DEFAULT_LENGTH * DISTANCE[STATIC_OBJ_NAME]
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
            local select_tag = ("%s bounding:in"):format(obj_name)
            local scene_aabb = math3d.aabb()
            local is_valid = false
            for e in w:select(select_tag) do
                if e.bounding.scene_aabb ~= mc.NULL and math3d.aabb_isvalid(e.bounding.scene_aabb) then
                    scene_aabb = math3d.aabb_merge(scene_aabb, e.bounding.scene_aabb)
                    is_valid = true
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
                create_clear_static_prefab_entity() 
            end
        end
    end

    adjust_prefab(STATIC_OBJ_NAME, STATIC_QUEUE_NAME)
    for e in w:select "INIT clear_smt_prefab eid:in" do
        w:remove(e.eid) 
    end
end

function mts_sys:entity_remove()
    for e in w:select "REMOVED clear_smt_prefab" do
        update_current_rt_handle(STATIC_QUEUE_NAME)
    end
end

local S = ltask.dispatch()

function S.create_mem_texture_static_prefab(prefab_path, width, height, rotation, distance)

    local function create_mem_texture_prefab(obj_name ,queue_name)

        world:create_instance {
            prefab = prefab_path,
            group  = ig.groupid(obj_name),
            on_ready = function (inst)
                local alleid = inst.tag['*']
                for _, eid in ipairs(alleid) do
                    local ee <close> = world:entity(eid, "visible_state?in mesh?in scene?in mem_texture_ready?out")
                    if ee.mesh and ee.visible_state then
                        ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                        ivs.set_state(ee, queue_name, true)
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

    DISTANCE[STATIC_OBJ_NAME] = distance
    create_mem_texture_prefab(STATIC_OBJ_NAME ,STATIC_QUEUE_NAME)
    adjust_camera_rotation(STATIC_QUEUE_NAME)
    return get_current_rt_handle(STATIC_QUEUE_NAME)
end

