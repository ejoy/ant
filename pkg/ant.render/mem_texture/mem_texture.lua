local ecs = ...
local world = ecs.world
local w = world.w
local mt_sys = ecs.system "mem_texture_system"
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

local MEM_TEXTURE_VIEWID <const> = hwi.viewid_get "mem_texture"
local OBJ_NAME <const> =  "mem_texture_obj"
local QUEUE_NAME <const> = "mem_texture_queue"
local DEFAULT_RT_WIDTH, DEFAULT_RT_HEIGHT <const> = 512, 512
local RB_FLAGS <const> = sampler{
    MIN =   "LINEAR",
    MAG =   "LINEAR",
    U   =   "CLAMP",
    V   =   "CLAMP",
    RT  =   "RT_ON",
}

local function register_mem_texture_group()
    w:register{name = OBJ_NAME}
    local gid = ig.register(OBJ_NAME)
    ig.enable(gid, OBJ_NAME, true)
end

local function register_mem_texture_render_queue()
    w:register{name = QUEUE_NAME}
end

local function register_mem_texture_material_queue()
    local mem_texture_material_idx = queuemgr.material_index("main_queue")
    queuemgr.register_queue(QUEUE_NAME, mem_texture_material_idx)
end

local function create_mem_texture_queue()

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
                        r = {0.6, 0, 0},
                        t = {0, 80, -50, 0},
                        updir = {0.0, 1.0, 0.0}
                },
                  camera = {
                    frustum = {
                        aspect = 4/3,
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
				viewid		= MEM_TEXTURE_VIEWID,
				view_mode 	= "s",
                clear_state = {
                    color = 0x00000000,
                    depth = 0.0,
                    clear = "CD",
                },
				view_rect	= {x = 0, y = 0, w = mqvr.w, h = mqvr.h},
				fb_idx		= fbidx,
			},
            [QUEUE_NAME]         = true,
			queue_name			 = QUEUE_NAME,
            visible = true,
		}
	}
end

local function exist_prefab()
    local select_tag = ("%s"):format(OBJ_NAME)
    return w:first(select_tag)
end

function mt_sys:init()
    register_mem_texture_group()
    register_mem_texture_render_queue()
    register_mem_texture_material_queue()
end

function mt_sys:init_world()
    create_mem_texture_queue()
end

function mt_sys:update_filter()

    local function create_clear_prefab_entity()
        world:create_entity {
            policy = {
                "ant.render|clear_mt_prefab"
            },
            data = {
                clear_mt_prefab = true
            },
        }
    end

    local function adjust_camera_pos(camera, aabb)
        if not math3d.aabb_isvalid(aabb) then return end
        -- 1.get aabb_center/extents in world space
        -- 2.get camera srt in world space
        -- 3.transform aabb to view space
        -- 4.get fov
        local world_points = math3d.aabb_points(aabb)
        local world_min, world_max = math3d.minmax(world_points)
        local world_center, extents = math3d.mul(0.5, math3d.add(world_max, world_min)), math3d.mul(0.5, math3d.sub(world_max, world_min))
        local view_dir = math3d.todirection(camera.scene.r)
        local view_len = math3d.length(math3d.mul(2, extents))
        local camera_pos = math3d.sub(world_center, math3d.mul(view_dir, view_len))
        camera_pos = math3d.sub(camera_pos, math3d.vector(0, 10, 0))
        iom.set_position(camera, camera_pos) 

         local worldmat = math3d.matrix(camera.scene)
        local viewmat = math3d.inverse(worldmat)
        local view_min, view_max = math3d.minmax(world_points, viewmat)
        local view_center = math3d.mul(0.5, math3d.add(view_max, view_min))
        local delta_y, delta_z = math3d.index(math3d.sub(view_max, view_center), 2), math3d.index(view_max, 3)
        local fovy = math.deg(math.atan(delta_y / delta_z)) * 2
        icamera.set_frustum_fov(camera, fovy)
    end


    if exist_prefab() then
        local scene_aabb = math3d.aabb()
        local select_tag = ("filter_result %s visible_state:in render_object:in material:in bounding?in filter_material:in scene:in"):format(OBJ_NAME)
        for e in w:select(select_tag) do
            if e.visible_state[QUEUE_NAME] then
                local fm = e.filter_material
                local mi = fm["main_queue"]
                fm[QUEUE_NAME] = mi
                R.set(e.render_object.rm_idx, queuemgr.material_index(QUEUE_NAME), mi:ptr())
                local worldmat = math3d.matrix(e.scene)
                local current_scene_aabb = math3d.aabb_transform(worldmat, e.bounding.aabb)
                scene_aabb = math3d.aabb_merge(scene_aabb, current_scene_aabb)
            end
        end

        select_tag = ("%s camera_ref:in"):format(QUEUE_NAME)
        local mtq = w:first(select_tag)
        local camera<close> = world:entity(mtq.camera_ref, "scene:update camera:in")
        adjust_camera_pos(camera, scene_aabb)

        create_clear_prefab_entity()
    end
end

function mt_sys:entity_init()

    local function remove_prefab()
        local select_tag = ("%s eid:in"):format(OBJ_NAME)
        for e in w:select(select_tag) do
            w:remove(e.eid)
        end
    end

    for e in w:select "INIT clear_mt_prefab eid:in" do
        remove_prefab()
        w:remove(e.eid) 
    end
end

function mt_sys:entity_remove()

    local function update_current_rt_handle()
        local select_tag = ("%s render_target:update"):format(QUEUE_NAME)
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
        irq.update_rendertarget(QUEUE_NAME, mtq.render_target)
    end

    for e in w:select "REMOVED clear_mt_prefab" do
        update_current_rt_handle()
    end
end

local S = ltask.dispatch()

function S.create_mem_texture_prefab(prefab_path, width, height, rotation)

    local function create_mem_texture_prefab()
        world:create_instance {
            prefab = prefab_path,
            group  = ig.groupid(OBJ_NAME),
            on_ready = function (inst)
                local alleid = inst.tag['*']
                for _, eid in ipairs(alleid) do
                    local ee <close> = world:entity(eid, "visible_state?in mesh?in scene?in")
                    if ee.mesh and ee.visible_state then
                        ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                        ivs.set_state(ee, QUEUE_NAME, true)
                    end
                    if ee.scene and ee.scene.parent == 0 then
                        iom.set_rotation(ee, math3d.quaternion(rotation))
                    end
                end
            end
        }
        ig.enable_from_name(OBJ_NAME, "view_visible", true)
    end

    local function adjust_camera_rot()
        local select_tag = ("%s camera_ref:in"):format(QUEUE_NAME)
        local mtq = w:first(select_tag)
        local camera<close> = world:entity(mtq.camera_ref, "scene:update camera:in")
        iom.set_rotation(camera, math3d.quaternion(rotation)) 
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

    local function get_current_rt_handle()
        local select_tag = ("%s render_target:update"):format(QUEUE_NAME)
        local mtq = w:first(select_tag)
        local fbidx = mtq.render_target.fb_idx
        resize_framebuffer(fbidx)
        irq.update_rendertarget(QUEUE_NAME, mtq.render_target)
        return fbmgr.get_rb(fbidx, 1).handle
    end

    create_mem_texture_prefab()
    --adjust_camera_rot()
    return get_current_rt_handle()
end
