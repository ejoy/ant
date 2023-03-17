local ecs = ...
local world = ecs.world
local w = world.w
local ui_rt_sys = ecs.system "ui_rt_system"
local ivs		= ecs.import.interface "ant.scene|ivisible_state"
local math3d = require "math3d"
local ltask     = require "ltask"
local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler

local ui_rt_group_id = 110000

local rt2g_table = {}
local g2rt_table = {}

local rb_flags = sampler{
    MIN="POINT",
    MAG="POINT",
    U="CLAMP",
    V="CLAMP",
    RT="RT_ON",
}

local function gen_group_id(name)
    local queuename = name.."_queue"
    local gid = ui_rt_group_id + 1
    ui_rt_group_id = gid
    rt2g_table[name] = gid
    g2rt_table[gid]  = name
    w:register{ name = name.."_obj"}
    w:register{ name = queuename}
    w:register{ name = queuename.."_cull"}
    w:register{ name = queuename.."_visible"}
end


function ui_rt_sys:data_changed()
    for gid, name in pairs(g2rt_table) do
        local g = ecs.group(gid)
        local obj = name.."_obj"
        local queue_visible = name.."_queue_visible"
        g:enable(obj)
        local s_select = ("%s%s%s"):format(obj, " render_object", " visible_state?in")
        local s_visible = ("%s%s"):format(queue_visible, "?out")
        for e in w:select(s_select) do
            w:extend(e, s_visible)
            e[queue_visible] = true
        end        
    end
end

--[[ function ui_rt_sys:update_camera_depend()
    for _, name in pairs(g2rt_table) do
        local s_select = ("%s%s"):format(name, "_queue camera_ref:in")
        for qe in w:select(s_select) do
            local ce = world:entity(qe.camera_ref, "camera:in")
            local camera = ce.camera
            camera.viewmat.m = math3d.inverse(ce.scene.worldmat)
            camera.projmat.m = math3d.projmat(camera.frustum, true)
            camera.viewprojmat.m = math3d.mul(camera.projmat, camera.viewmat)
        end        
    end
end ]]

local S = ltask.dispatch()

--local lastname = "blit_shadowmap"

function S.render_target_create(width, height, name)
    local viewid = viewidmgr.generate(name)
    local fbidx = fbmgr.create(
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "RGBA8", flags = rb_flags}},
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "D16", flags = rb_flags}} 
    )
    
    local id = fbmgr.get_rb(fbidx, 1).handle
    local queuename = name .. "_queue"
    gen_group_id(name)
    ecs.create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|watch_screen_buffer",
			"ant.general|name",
		},
		data = {
            camera_ref = ecs.create_entity{
                policy = {
                    "ant.general|name",
                    "ant.camera|camera"
                },
                data = {
                    scene = {
                        r = {1, 0, 0},
                        t = {0, 5, -5, 0},
                        updir = {0.0, 1.0, 0.0}
                },
                  camera = {
                    frustum = {
                        aspect = 1.3333333333333333,
                        f = 100,
                        fov = 60,
                        n = 1,
                    }
                  },
                  exposure = {
                    type          = "manual",
                    aperture      = 16.0,
                    shutter_speed = 0.008,
                    ISO           = 20
                  },
                  name = name .. "_camera",
                }
            },
			render_target = {
				viewid		= viewid,
				view_mode 	= "s",
                clear_state = {
                    color = 0x000000ff,
                    depth = 0.0,
                    clear = "CD",
                },
				view_rect	= {x = 0, y = 0, w = width, h = height},
				fb_idx		= fbidx,
			},
            [queuename]         = true,
			name 				= queuename,
			queue_name			= queuename,
            visible = true,
			watch_screen_buffer	= true,
		}
	}
    lastname = name
    return id
end

local iUiRt = ecs.interface "iuirt"

function iUiRt.get_group_id(name)
    return rt2g_table[name]
end

local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"

function iUiRt.calc_camera_t(queuename, aabb)
    local select_condition = queuename .. " camera_ref:in"
    local rtq = w:first(select_condition)
    if rtq then
        local rt_camera<close> = w:entity(rtq.camera_ref, "scene:update")
        local aabb_min, aabb_max = math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
        local triple_offset = 3 * math3d.length(math3d.sub(aabb_max, aabb_min))
        local unit_dir = math3d.normalize(rt_camera.scene.t)
       iom.set_position(rt_camera, math3d.mul(unit_dir, triple_offset)) 
       --iom.set_position(rt_camera, math3d.vector({0, 5, -5, 0})) 
    end
end