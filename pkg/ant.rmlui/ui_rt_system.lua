local ecs = ...
local world = ecs.world
local w = world.w
local ui_rt_sys = ecs.system "ui_rt_system"
local ivs		= ecs.require "ant.render|visible_state"
local math3d    = require "math3d"
local ltask     = require "ltask"
local bgfx 		= require "bgfx"

local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler
local iom       = ecs.require "ant.objcontroller|obj_motion"
local icamera	= ecs.require "ant.camera|camera"
local irq		= ecs.require "ant.render|render_system.renderqueue"
local ig        = ecs.require "ant.group|group"
local R             = world:clibs "render.render_material"
local queuemgr      = ecs.require "ant.render|queue_mgr"
local ServiceResource = ltask.queryservice "ant.resource_manager|resource"
local VIEWIDS = require "ui_rt_global"
local OBJNAMES, QUEUENAMES = {}, {}
local iUiRt = {}
local fb_cache, rb_cache = {}, {}
local rt_table = {}

local S = ltask.dispatch()

local rb_flags = sampler{
    MIN="POINT",
    MAG="POINT",
    U="CLAMP",
    V="CLAMP",
    RT="RT_ON",
}

local function gen_group_id(rt_name)
    local objname = rt_name .. "_obj"
    local queuename = rt_name .. "_queue"
    OBJNAMES[rt_name] = objname
    QUEUENAMES[rt_name] = queuename
    w:register{ name = objname }
    w:register{ name = queuename }
    local gid = ig.register(objname)
    ig.enable(gid, objname, true)
end

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

local function create_rt_queue(width, height, name, fbidx)
    local viewid = VIEWIDS[name]
    gen_group_id(name)
    local queuename = QUEUENAMES[name]
    local ui_rt_material_idx = queuemgr.material_index("main_queue")
    queuemgr.register_queue(queuename, ui_rt_material_idx)
    return world:create_entity {
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
                        r = {1, 0, 0},
                        t = {0, 8, -5, 0},
                        updir = {0.0, 1.0, 0.0}
                },
                  camera = {
                    frustum = {
                        aspect = 1,
                        f = 300,
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
				viewid		= viewid,
				view_mode 	= "s",
                clear_state = {
                    color = 0x00000000,
                    depth = 0.0,
                    clear = "CD",
                },
				view_rect	= {x = 0, y = 0, w = width, h = height},
				fb_idx		= fbidx,
			},
            [queuename]         = true,
			queue_name			= queuename,
            visible = true,
		}
	}
end

local function create_fbidx(width, height)
    return fbmgr.create(
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "RGBA8", flags = rb_flags}},
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "D16", flags = rb_flags}}
    )
end

local function update_fb(old_fbidx, width, height, queuename)
    if width == 0 or height == 0 then return end
    if old_fbidx then
        fbmgr.destroy(old_fbidx)
    end
    local select_tag = queuename .. " render_target:in camera_ref:in"
    local qe = w:first(select_tag)
    if not qe then
        return
    end
    local rt = qe.render_target
    local vr = rt.view_rect
    vr.w, vr.h = width, height
    
    if qe.camera_ref then
		local camera <close> = world:entity(qe.camera_ref)
		icamera.set_frustum_aspect(camera, vr.w/vr.h)
	end

    local fbidx = fbmgr.create(
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "RGBA8", flags = rb_flags}},
        {rbidx = fbmgr.create_rb{w = width, h = height, layers = 1, format = "D16", flags = rb_flags}} 
    )
    rt.fb_idx = fbidx
    resize_framebuffer(width, height, fbidx)
    irq.update_rendertarget(queuename, rt)
    return fbidx
end

local function create_render_target_instance(width, height, rt_name, rt)
    rt.fb_idx, rt.w, rt.h = create_fbidx(width, height), width, height
    rt.rt_id = create_rt_queue(width, height, rt_name, rt.fb_idx)
    rt.rt_texture_id = ltask.call(ServiceResource, "texture_register_id")
    rt.rt_handle = fbmgr.get_rb(rt.fb_idx, 1).handle
    ltask.call(ServiceResource, "texture_set_handle", rt.rt_texture_id, rt.rt_handle)
end

function S.render_target_update(width, height, rt_name)
    local rt = rt_table[rt_name]
    if rt then -- adjust width/height
        if width ~= rt.w or height ~= rt.h then
            rt.fb_idx = update_fb(rt.fb_idx, width, height, QUEUENAMES[rt_name]) 
        end
        rt.w, rt.h = width, height
    else -- first create rt
        rt = {}
        rt_table[rt_name] = rt
        create_render_target_instance(width, height, rt_name, rt)
    end
    return rt.rt_texture_id
end

local function calc_camera_t(queuename, aabb, scene, distance)
    if scene and scene.parent ~= 0 then
        local p<close> = world:entity(scene.parent, "scene?in")
        if p.scene then
            aabb = math3d.aabb_transform(math3d.matrix(p.scene), aabb)
        end
    end
    local select_condition = queuename .. " camera_ref:in"
    local rtq = w:first(select_condition)
    if rtq then
        local rt_camera<close> = world:entity(rtq.camera_ref, "scene:update")
        local aabb_min, aabb_max = math3d.array_index(aabb, 1), math3d.array_index(aabb, 2)
        local triple_offset = 3 * math3d.length(math3d.sub(aabb_max, aabb_min))
        local unit_dir = math3d.normalize(rt_camera.scene.t)
        if distance then
            iom.set_position(rt_camera, math3d.mul(unit_dir, distance)) 
        else
            iom.set_position(rt_camera, math3d.mul(unit_dir, triple_offset)) 
        end
    end 
end

local function delete_rt_prefab(rt_name)
    local obj_name = OBJNAMES[rt_name]
    ig.check(obj_name)
    local select_tag = obj_name .. " eid:in"
    for e in w:select(select_tag) do
        w:remove(e.eid)
    end
end

function iUiRt.get_group_id(rt_name)
    local on = OBJNAMES[rt_name]
    if ig.has(on) then
        return ig.groupid(on)
    end
end

function iUiRt.set_rt_prefab(rt_name, focus_path, focus_srt, distance, clear_color, on_message)
    if not iUiRt.get_group_id(rt_name) then return end
    local rt = rt_table[rt_name]
    if not rt then
        rt = {}
        rt_table[rt_name] = rt
        create_render_target_instance(1, 1, rt_name, rt)
    elseif not rt.rt_handle then
        local fbidx = update_fb(rt.fb_idx, rt.w, rt.h, QUEUENAMES[rt_name])
        rt.fb_idx = fbidx
        if fbidx then
            rt.rt_handle = fbmgr.get_rb(fbidx, 1).handle
            ltask.call(ServiceResource, "texture_set_handle", rt.rt_texture_id, rt.rt_handle) 
        end
    end
    
    if rt.prefab_path then
        if rt.prefab_path == focus_path then
            return rt.prefab
        else
            delete_rt_prefab(rt_name) 
        end
    end
    
    local srt = focus_srt
    rt.distance = distance
    local focus_instance = world:create_instance {
        prefab = focus_path,
        group = ig.groupid(OBJNAMES[rt_name]),
        on_message = on_message,
        on_ready = function (inst)
            local alleid = inst.tag['*']
            if clear_color then
                irq.set_view_clear_color(QUEUENAMES[rt_name], clear_color)  
            end
            local re <close> = world:entity(alleid[1])
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
                local ee <close> = world:entity(eid, "visible_state?in focus_obj?update mesh?in")
                if ee.mesh then
                    if ee.visible_state then
                        ivs.set_state(ee, "main_view|selectable|cast_shadow", false)
                        ivs.set_state(ee, QUEUENAMES[rt_name], true)
                        ee.focus_obj = true
                    end 
                end
            end
        end
    }
    ig.enable_from_name(OBJNAMES[rt_name], "view_visible", true)
    rt.prefab = focus_instance 
    rt.prefab_path = focus_path
    return rt.prefab
end


local frame_tick = 0
local dead_timestamp = 60
local reload_timestamp = 1

function ui_rt_sys:data_changed()
    frame_tick = frame_tick + 1
    local function get_rt_texture_id_table()
        local rtid_table = {}
        local rtid_rt_table = {}
        for _, rt in pairs(rt_table) do
            if rt.timestamp then
                rtid_table[#rtid_table+1] = rt.rt_texture_id
                rtid_rt_table[rt.rt_texture_id] = rt
            end
        end
        return rtid_table, rtid_rt_table
    end

    if frame_tick % dead_timestamp == 0 then
        local rtid_table, rtid_rt_table = get_rt_texture_id_table()
        if #rtid_table > 0 then
            ltask.fork(function ()
                local rtid_timestamp_table = ltask.call(ServiceResource, "texture_timestamp", rtid_table) 
                for rt_texture_id, rt_timestamp in pairs(rtid_timestamp_table) do
                    local rt = rtid_rt_table[rt_texture_id]
                    rt.timestamp = rt_timestamp
                end
            end)   
        end       
    end

    if frame_tick % reload_timestamp == 0 then
        local rtid_table, rtid_rt_table = get_rt_texture_id_table()
        if #rtid_table > 0 then
            ltask.fork(function ()
                local rtid_timestamp_table = ltask.call(ServiceResource, "texture_timestamp", rtid_table) 
                for rt_texture_id, rt_timestamp in pairs(rtid_timestamp_table) do
                    local rt = rtid_rt_table[rt_texture_id]
                    rt.timestamp = rt_timestamp
                end
            end)   
        end       
    end

    for rt_name, rt in pairs(rt_table) do
        if rt.timestamp and rt.timestamp > dead_timestamp and rt.rt_handle then
            ltask.fork(function ()
                local already_dead = ltask.call(ServiceResource, "texture_destroy_handle", rt. rt_texture_id)
                if already_dead then
                    bgfx.destroy(rt.rt_handle)
                    rt.rt_handle = nil
                end
            end) 
        elseif rt.timestamp and rt.timestamp < reload_timestamp and (not rt.rt_handle) then
            local fbidx = update_fb(rt.fb_idx, rt.w, rt.h, QUEUENAMES[rt_name])
            rt.fb_idx = fbidx
            local rt_handle = fbmgr.get_rb(fbidx, 1).handle
            rt.rt_handle = rt_handle
            ltask.call(ServiceResource, "texture_set_handle", rt.rt_texture_id, rt.rt_handle)                
        end
    end
end

function ui_rt_sys:update_filter()
    for rt_name, rt in pairs(rt_table) do
        local distance = rt_table[rt_name].distance
        local queuename = QUEUENAMES[rt_name]
        local objname = OBJNAMES[rt_name]
        if objname then
            local select_tag = ("filter_result %s visible_state:in render_object:update filter_material:in render_object?in scene?update eid:in bounding?in focus_obj?in"):format(OBJNAMES[rt_name])
            for e in w:select(select_tag) do
                if e.visible_state[queuename] then
                    local fm = e.filter_material
                    local mi = fm["main_queue"]
                    fm[queuename] = mi
                    --fm[queuename]:set_state(bgfx.make_state(DEFAULT_STATE))
                    R.set(e.render_object.rm_idx, queuemgr.material_index(queuename), mi:ptr())
                    if e.bounding and e.focus_obj then
                        calc_camera_t(queuename, e.bounding.scene_aabb, e.scene, distance) 
                    end
                end
                rt.timestamp = 0
                print(objname)
                print("end")
            end 
        end
    end
end

return iUiRt
