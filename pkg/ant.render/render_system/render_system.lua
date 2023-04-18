local ecs = ...
local world = ecs.world
local w = world.w

local bgfx 		= require "bgfx"
local math3d 	= require "math3d"
local viewidmgr = require "viewid_mgr"
local irender	= ecs.import.interface "ant.render|irender"
local ivs		= ecs.import.interface "ant.scene|ivisible_state"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local itimer	= ecs.import.interface "ant.timer|itimer"
local irl		= ecs.import.interface "ant.render|irender_layer"

local render_sys= ecs.system "render_system"

local rendercore= ecs.clibs "render.core"
local null = rendercore.null()

local function update_viewid_remappings()
    bgfx.set_view_order(viewidmgr.remapping())
    for n, viewid in pairs(viewidmgr.all_bindings()) do
		bgfx.set_view_name(viewid, n)
	end
end

local def_group_id<const> = 0
local vg_sys = ecs.system "viewgroup_system"
function vg_sys:init()
    ecs.group(def_group_id):enable "view_visible"
	ecs.group_flush()
end

function render_sys:component_init()
	for e in w:select "INIT render_object filter_material:update render_object_update?out" do
		e.filter_material = e.filter_material or {}
		e.render_object_update = true
	end
end

local function update_ro(ro, m)
	ro.vb_start = m.vb.start
	ro.vb_num = m.vb.num
	ro.vb_handle = m.vb.handle

	local ib = m.ib
	if ib then
		ro.ib_start = m.ib.start
		ro.ib_num = m.ib.num
		ro.ib_handle = m.ib.handle
	end
end

local RENDER_ARGS = setmetatable({}, {__index = function (t, k)
	local v = {
		queue_visible_id	= w:component_id(k .. "_visible"),
		queue_cull_id		= w:component_id(k .. "_cull"),
		material_index		= irender.material_index(k) or 0,
	}
	t[k] = v
	return v
end})

function render_sys:entity_init()
	for e in w:select "INIT material_result:in render_object:update filter_material:in" do
		local mr = e.material_result
		local fm = e.filter_material
		local mi = mr.object:instance()
		fm["main_queue"] = mi
		local ro = e.render_object
		ro.mat_def = mi:ptr()
	end

	for e in w:select "INIT mesh?in simplemesh?in render_object:update" do
		local m = e.mesh or e.simplemesh
		if m then
			update_ro(e.render_object, m)
		end
	end

	for e in w:select "INIT render_layer?update render_object:update" do
		local rl = e.render_layer
		if not rl  then
			rl = "opacity"
			e.render_layer = rl
		end

		e.render_object.render_layer = assert(irl.layeridx(rl))
	end

	for qe in w:select "INIT queue_name:in render_target:in" do
		local qn = qe.queue_name
		RENDER_ARGS[qn].viewid = qe.render_target.viewid
	end

	for e in w:select "INIT render_object visible_state:in filter_result:new" do
		local vs = e.visible_state
		for qe in w:select "queue_name:in camera_ref" do
			local qn = qe.queue_name
			local qn_visible = qn .. "_visible"
			e[qn_visible] = vs[qn]
			w:extend(e, qn_visible .. "?out")
		end
		e.filter_result = true
	end
end

local time_param = math3d.ref(math3d.vector(0.0, 0.0, 0.0, 0.0))
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


function render_sys:begin_filter()
	

end

function render_sys:scene_update()
	for e in w:select "scene_changed scene:in render_object:update" do
		e.render_object.worldmat = e.scene.worldmat
	end
end

function render_sys:render_submit()
	if viewidmgr.need_update_remapping() then
		update_viewid_remappings()
		viewidmgr.clear_remapping()
	end
	for qe in w:select "visible camera_ref:in render_target:in" do
		local viewid = qe.render_target.viewid
		local camera <close> = w:entity(qe.camera_ref, "scene_changed?in camera_changed?in")
		if camera.scene_changed or camera.camera_changed then
			w:extend(camera, "camera:in")
			bgfx.set_view_transform(viewid, camera.camera.viewmat, camera.camera.projmat)
		end
	end

	w:clear "render_args"
	for qe in w:select "visible queue_name:in render_target:in render_args:new" do
		local rt = qe.render_target
		local viewid = rt.viewid

		bgfx.touch(viewid)
		qe.render_args = RENDER_ARGS[qe.queue_name]
	end

	rendercore.submit()
end

function render_sys:entity_remove()
	for e in w:select "REMOVED render_object:update filter_material:in" do
		local fm = e.filter_material
		local ro = e.render_object
		local mm = {}
		for k, m in pairs(fm) do
			if mm[m] == nil then
				mm[m] = true
				m:release()
				fm[k] = nil
			end
		end
		for k in pairs(ro) do
			if k:match "mat_" then
				ro[k] = null
			end
		end
	end
end

local function check_set_depth_state_as_equal(state)
	local ss = bgfx.parse_state(state)
	ss.DEPTH_TEST = "EQUAL"
	local wm = ss.WRITE_MASK
	ss.WRITE_MASK = wm and wm:gsub("Z", "") or "RGBA"
	return bgfx.make_state(ss)
end

local material_cache = {__mode="k"}

function render_sys:update_filter()
	if irender.use_pre_depth() then
		--we should check 'filter_result' here and change the default material
		--because render entity will change it's visible state after it created
		--but not create this new material instance in entity_init stage
		for e in w:select "filter_result main_queue_visible render_layer:in render_object:update filter_material:in" do
			if e.render_layer == "opacity" then
				local ro = e.render_object
				local fm = e.filter_material

				local mo = fm.main_queue:get_material()

				local state = check_set_depth_state_as_equal(mo:get_state())
				local new_mo = irender.create_material_from_template(mo, state, material_cache)
				fm.main_queue:replace_material(new_mo)
				ro.mat_def = fm.main_queue:ptr()
			end
		end
	end
	w:clear "render_object_update"
end

function render_sys:end_filter()
	w:clear "filter_result"
end