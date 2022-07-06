local ecs = ...
local world = ecs.world
local w = world.w

local bgfx 		= require "bgfx"
local math3d 	= require "math3d"
local template	= import_package "ant.general".template
local irender	= ecs.import.interface "ant.render|irender"
local ies		= ecs.import.interface "ant.scene|ifilter_state"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local itimer	= ecs.import.interface "ant.timer|itimer"
local render_sys = ecs.system "render_system"

local def_group_id<const> = 0
local vg_sys = ecs.system "viewgroup_system"
function vg_sys:init()
    ecs.group(def_group_id):enable "view_visible"
	ecs.group_flush()
end

local viewidmgr = require "viewid_mgr"
for n, b in pairs(viewidmgr.all_bindings()) do
	for viewid=b[1], b[1]+b[2]-1 do
		bgfx.set_view_name(viewid, n .. "_" .. viewid)
	end
end

function render_sys:component_init()
	for e in w:select "INIT render_object:update filter_material:out render_object_update?out" do
		e.render_object = e.render_object or {}
		e.filter_material = {}
		e.render_object_update = true
	end
end

function render_sys:entity_init()
	for qe in w:select "INIT primitive_filter:in queue_name:in" do
		local pf = qe.primitive_filter

		pf._DEBUG_filter_type = pf.filter_type
		pf.filter_type = ies.filter_mask(pf.filter_type)
		pf._DEBUG_excule_type = pf.exclude_type
		pf.exclude_type = pf.exclude_type and ies.filter_mask(pf.exclude_type) or 0
	end

	for e in w:select "INIT material_result:in scene:in render_object:in" do
		local ro = e.render_object
		local mr = e.material_result
		ro.material = mr.object:instance()
        ro.fx     	= mr.fx
		
		ro.worldmat = e.scene.worldmat
	end
end

local time_param = math3d.ref(math3d.vector(0.0, 0.0, 0.0, 0.0))
local starttime = itimer.current()
local timepassed = 0.0
local function update_timer_param()
	local sa = imaterial.system_attribs()
	timepassed = timepassed + itimer.delta()
	time_param.v = math3d.set_index(time_param, 1, timepassed*0.001, itimer.delta()*0.001)
	sa:update("u_time", time_param)
end

function render_sys:commit_system_properties()
	update_timer_param()
end

local function has_filter_tag(t, filter)
	for _, fn in ipairs(filter) do
		if fn == t then
			return true
		end
	end
end

function render_sys:update_filter()
	w:clear "filter_result"
    for e in w:select "render_object_update render_object:in filter_result:new" do
        local ro = e.render_object
        local filterstate = ro.filter_state
		local st = ro.fx.setting.surfacetype

		e[st] = true
		w:sync(st .. "?out", e)

		for qe in w:select "queue_name:in primitive_filter:in" do
			local qn = qe.queue_name
			local function mark_tags(add)
				local qn_visible = qn .. "_visible"
				e[qn_visible] = add
				w:sync(qn_visible .. "?out", e)
			end

			local pf = qe.primitive_filter
			if has_filter_tag(st, pf) then
				local add = ((filterstate & pf.filter_type) ~= 0) and ((filterstate & pf.exclude_type) == 0)
				mark_tags(add)
			end
		end
		e.filter_result = true
    end
end

local keys = template.keys
local select_cache = template.new "view_visible %s_visible %s_cull:absent %s render_object:in filter_material:in"

local function load_select_key(qn, fn)
	local k = keys[qn][qn][fn]
	return select_cache[k]
end

local function submit_render_objects(viewid, filter, qn)
	for _, fn in ipairs(filter) do
		for e in w:select(load_select_key(qn, fn)) do
			irender.draw(viewid, e.render_object, e.filter_material[qn])
		end
	end
end

function render_sys:render_submit()
	for qe in w:select "visible queue_name:in camera_ref:in render_target:in primitive_filter:in" do
		local camera = world:entity(qe.camera_ref).camera
		local rt = qe.render_target
		local viewid = rt.viewid

		bgfx.touch(viewid)
		bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)
		submit_render_objects(viewid, qe.primitive_filter, qe.queue_name)
    end
end

function render_sys:entity_remove()
	for e in w:select "REMOVED render_object:in filter_material:in" do
		local function release(m)
			if m.material then
				m.material:release()
				m.material = nil
			end
		end
		release(e.render_object)
		for _, m in pairs(e.filter_material) do
			release(m)
		end
	end
end

local s = ecs.system "end_filter_system"

local function check_set_depth_state_as_equal(state)
	local ss = bgfx.parse_state(state)
	ss.DEPTH_TEST = "EQUAL"
	local wm = ss.WRITE_MASK
	ss.WRITE_MASK = wm and wm:gsub("Z", "") or "RGBA"
	return bgfx.make_state(ss)
end

function s:end_filter()
	if irender.use_pre_depth() then
		for e in w:select "filter_result main_queue_visible opacity render_object:in" do
			local ro = e.render_object
			local rom = ro.material
			rom:get_material():set_state(check_set_depth_state_as_equal(rom:get_state()))
		end
	end
	w:clear "render_object_update"
end