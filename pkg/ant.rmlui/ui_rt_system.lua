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
local mc 		= import_package "ant.math".constant
local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
local iUiRt = ecs.interface "iuirt"
local icamera	= ecs.import.interface "ant.camera|icamera"
local irq		= ecs.import.interface "ant.render|irenderqueue"
local ui_rt_group_id = 110000
local fb_cache, rb_cache = {}, {}
local rt2g_table = {}
local g2rt_table = {}
local g2pf_table = {}
local focused_rt_table = {}
local R             = ecs.clibs "render.render_material"
local queuemgr      = renderpkg.queuemgr

local rb_flags = sampler{
    MIN="POINT",
    MAG="POINT",
    U="CLAMP",
    V="CLAMP",
    RT="RT_ON",
}

local function gen_group_id(name)
    if not rt2g_table[name] then
        local queuename = name.."_queue"
        local gid = ui_rt_group_id + 1
        ui_rt_group_id = gid
        rt2g_table[name] = gid
        g2rt_table[gid]  = name
        w:register{ name = name.."_obj"}
        w:register{ name = queuename}
    end
end


local S = ltask.dispatch()

--local lastname = "blit_shadowmap"
local function resize_framebuffer(w, h, fbidx)
	if fbidx == nil or fb_cache[fbidx] then
		return 
	end

	local fb = fbmgr.get(fbidx)


	local changed = false
	local rbs = {}
	for _, attachment in ipairs(fb)do
		local rbidx = attachment.rbidx
		rbs[#rbs+1] = attachment
		local c = rb_cache[rbidx]
		if c == nil then
			changed = fbmgr.resize_rb(rbidx, w, h) or changed
			rb_cache[rbidx] = changed
		else
			changed = true
		end
	end
	
	if changed then
		fbmgr.recreate(fbidx, fb)
	end
end

local lastname = "fxaa"

function S.render_target_create(width, height, name)
    if name == lastname then
        return
    end
    local viewid = viewidmgr.generate(name, lastname)
    lastname = name
    local fbidx = fbmgr.create(
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "RGBA8", flags = rb_flags}},
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "D16", flags = rb_flags}} 
    )
    
    local id = fbmgr.get_rb(fbidx, 1).handle
    local queuename = name .. "_queue"
    gen_group_id(name)
    local ui_rt_material_idx = queuemgr.material_index("main_queue")
    queuemgr.register_queue(queuename, ui_rt_material_idx)
    ecs.create_entity {
		policy = {
			"ant.render|render_queue",
			--"ant.render|watch_screen_buffer",
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
                        t = {0, 8, -5, 0},
                        updir = {0.0, 1.0, 0.0}
                },
                  camera = {
                    frustum = {
                        aspect = 1.3333333333333333,
                        f = 300,
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
			--watch_screen_buffer	= true,
		}
	}
    return id
end

function S.render_target_adjust(width, height, name)
    local queuename = name .. "_queue"
    local select_tag = queuename .. " render_target:in camera_ref:in queue_name:in"
    local qe = w:first(select_tag)
    local rt = qe.render_target
    local vr = rt.view_rect
    vr.w, vr.h = width, height
    
    if qe.camera_ref then
		local camera <close> = w:entity(qe.camera_ref)
		icamera.set_frustum_aspect(camera, vr.w/vr.h)
	end

    local fbidx = fbmgr.create(
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "RGBA8", flags = rb_flags}},
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "D16", flags = rb_flags}} 
    )
    rt.fb_idx = fbidx
    resize_framebuffer(width, height, fbidx)
    irq.update_rendertarget(qe.queue_name, rt)
    local id = fbmgr.get_rb(fbidx, 1).handle
    return id
end

local function calc_camera_t(queuename, aabb, scene)
    if scene and scene.parent ~= 0 then
        local p<close> = w:entity(scene.parent, "scene?in")
        if p.scene then
            aabb = math3d.aabb_transform(math3d.matrix(p.scene), aabb)
        end
    end
    local select_condition = queuename .. " camera_ref:in"
    local rtq = w:first(select_condition)
    if rtq then
        local rt_camera<close> = w:entity(rtq.camera_ref, "scene:update")
        local aabb_min, aabb_max = math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
        local triple_offset = 3 * math3d.length(math3d.sub(aabb_max, aabb_min))
        local unit_dir = math3d.normalize(rt_camera.scene.t)
       iom.set_position(rt_camera, math3d.mul(unit_dir, triple_offset)) 
    end 
end

function iUiRt.get_group_id(name)
    return rt2g_table[name]
end

function iUiRt.create_new_rt(rt_name, plane_path, light_path, focus_path, srt)
    local queue_name = rt_name .. "_queue"
    local gid = rt2g_table[rt_name]
    g2pf_table[gid] = focus_path
    local g = ecs.group(gid)
    local light_instance = g:create_instance(light_path)
    local plane_instance = g:create_instance(plane_path)
    local focus_instance = g:create_instance(focus_path)
    focus_instance.on_ready = function (inst)
        local alleid = inst.tag['*']
        local re <close> = w:entity(alleid[1])
        if srt.s then
            iom.set_scale(re, math3d.vector(srt.s))
        end
        if srt.r then
            iom.set_direction(re, math3d.vector(srt.r))
        end
        if srt.t then
            iom.set_position(re, math3d.vector(srt.t))
        end
        for _, eid in ipairs(alleid) do
            local ee <close> = w:entity(eid, "visible_state?in focus_obj?update mesh?in")
            if ee.mesh then
                if ee.visible_state then
                    ivs.set_state(ee, "main_view|selectable", false)
                    ivs.set_state(ee, queue_name, true)
                    ee.focus_obj = true
                end 
            end
        end
    end
    light_instance.on_ready = function (inst)
        local alleid = inst.tag['*']
        local re <close> = w:entity(alleid[1])
        for _, eid in ipairs(alleid) do
            local ee <close> = w:entity(eid, "visible_state?in")
            if ee.visible_state then
                ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                ivs.set_state(ee, queue_name, true)
            end 
        end
    end 
    plane_instance.on_ready = function (inst)
        local alleid = inst.tag['*']
        local re <close> = w:entity(alleid[1])
        iom.set_scale(re, math3d.vector(500, 1, 500))
        for _, eid in ipairs(alleid) do
            local ee <close> = w:entity(eid, "visible_state?in")
            if ee.visible_state then
                ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                ivs.set_state(ee, queue_name, true)
            end 
        end
    end 
    world:create_object(light_instance)
    world:create_object(plane_instance)
    world:create_object(focus_instance)
    g:enable "view_visible"
    g:enable "scene_update"
    return focus_instance
end

function iUiRt.open_ui_rt(rt_name, focus_path, srt)
    local queue_name = rt_name .. "_queue"
    local gid = rt2g_table[rt_name]
    local g = ecs.group(gid)
    local pre_focus_path = g2pf_table[gid]
    if pre_focus_path == focus_path then
        g:enable "view_visible"
        g:enable "scene_update"
        return
    else
        local enable_tag = rt_name .. "_obj"
        local select_tag = enable_tag .. " focus_obj:in eid:in"
        for ee in w:select(select_tag) do
            w:remove(ee.eid)
        end
        local focus_instance = g:create_instance(focus_path)
        focus_instance.on_ready = function (inst)
            local alleid = inst.tag['*']
            local re <close> = w:entity(alleid[1])
            if srt.s then
                iom.set_scale(re, math3d.vector(srt.s))
            end
            if srt.r then
                iom.set_direction(re, math3d.vector(srt.r))
            end
            if srt.t then
                iom.set_position(re, math3d.vector(srt.t))
            end
            for _, eid in ipairs(alleid) do
                local ee <close> = w:entity(eid, "visible_state?in focus_obj?update mesh?in")
                if ee.mesh then
                    if ee.visible_state then
                        ivs.set_state(ee, "main_view|selectable", false)
                        ivs.set_state(ee, queue_name, true)
                        ee.focus_obj = true
                    end 
                end
            end
        end
        world:create_object(focus_instance)
        g:enable "view_visible"
        g:enable "scene_update"
        g2pf_table[gid] = focus_path
        return focus_instance
    end
end

function iUiRt.close_ui_rt(rt_name)
    local gid = rt2g_table[rt_name]
    if gid then
        local g = ecs.group(gid)
        local enable_tag = rt_name .. "_obj"
        g:enable(enable_tag)
        g:disable "view_visible"
        g:disable "scene_update"
    end      
end 

local DEFAULT_STATE = {
    ALPHA_REF = 0,
    CULL = "CCW",
    DEPTH_TEST = "ALWAYS",
    MSAA = true,
    WRITE_MASK = "RGBAZ"
}

local bgfx      = require "bgfx"
function ui_rt_sys:update_filter()
    for gid, rt_name in pairs(g2rt_table) do
        local queue_name = rt_name .. "_queue"
        local obj_name = rt_name .. "_obj"
        local g = ecs.group(gid)
        g:enable(obj_name)
        local select_tag = "filter_result " .. obj_name .. " visible_state:in render_object:update filter_material:in render_object?in scene?update eid:in bounding?in focus_obj?in"
        for e in w:select(select_tag) do
            if e.visible_state[queue_name] then
                local fm = e.filter_material
                local mi = fm["main_queue"]
                fm[queue_name] = mi
                --fm[queue_name]:set_state(bgfx.make_state(DEFAULT_STATE))
                R.set(e.render_object.rm_idx, queuemgr.material_index(queue_name), mi:ptr())
                if e.bounding and e.focus_obj then
                    calc_camera_t(queue_name, e.bounding.scene_aabb, e.scene) 
                end
            end
        end
    end
end