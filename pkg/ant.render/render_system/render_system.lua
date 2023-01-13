local ecs = ...
local world = ecs.world
local w = world.w

local bgfx 		= require "bgfx"
local math3d 	= require "math3d"
local irender	= ecs.import.interface "ant.render|irender"
local ivs		= ecs.import.interface "ant.scene|ivisible_state"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local itimer	= ecs.import.interface "ant.timer|itimer"
local irl		= ecs.import.interface "ant.render|irender_layer"

local render_sys= ecs.system "render_system"

local rendercore= ecs.clibs "render.core"
local null = rendercore.null()

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

function render_sys:entity_init()
	for qe in w:select "INIT primitive_filter:in queue_name:in" do
		local pf = qe.primitive_filter

		pf._DEBUG_filter_type = pf.filter_type
		pf.filter_type = ivs.filter_mask(pf.filter_type)
		pf._DEBUG_excule_type = pf.exclude_type
		pf.exclude_type = pf.exclude_type and ivs.filter_mask(pf.exclude_type) or 0
	end

	
	for e in w:select "INIT material_result:in render_object:update filter_material:in" do
		local mr = e.material_result
		local fm = e.filter_material
		local mi = mr.object:instance()
		fm["main_queue"] = mi
		local ro = e.render_object
		ro.mat_mq = mi:ptr()
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
	w:clear "filter_result"
    for e in w:select "render_object_update render_object visible_state:in filter_result:new" do
        local fs = e.visible_state

		for qe in w:select "queue_name:in primitive_filter:in" do
			local qn = qe.queue_name
			local function mark_tags(add)
				local qn_visible = qn .. "_visible"
				e[qn_visible] = add
				w:extend(e, qn_visible .. "?out")
			end

			local pf = qe.primitive_filter
			local add = ((fs & pf.filter_type) ~= 0) and ((fs & pf.exclude_type) == 0)
			mark_tags(add)
		end
		e.filter_result = true
    end
end

function render_sys:scene_update()
	for e in w:select "scene_changed scene:in render_object:update" do
		e.render_object.worldmat = e.scene.worldmat
	end
end

function render_sys:render_submit()
	w:clear "render_args"
	for qe in w:select "visible queue_name:in camera_ref:in render_target:in render_args:new" do
		local rt = qe.render_target
		local viewid = rt.viewid

		bgfx.touch(viewid)
		local camera <close> = w:entity(qe.camera_ref, "scene_changed?in camera_changed?in")
		if camera.scene_changed or camera.camera_changed then
			w:extend(camera, "camera:in")
			bgfx.set_view_transform(viewid, camera.camera.viewmat, camera.camera.projmat)
		end

		qe.render_args = {
			viewid			= viewid,
			material_index	= rendercore.material_index(qe.queue_name) or 0,
		}
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

local s = ecs.system "end_filter_system"

local function check_set_depth_state_as_equal(state)
	local ss = bgfx.parse_state(state)
	ss.DEPTH_TEST = "EQUAL"
	local wm = ss.WRITE_MASK
	ss.WRITE_MASK = wm and wm:gsub("Z", "") or "RGBA"
	return bgfx.make_state(ss)
end

function s:update_filter()
	if irender.use_pre_depth() then
		for e in w:select "filter_result main_queue_visible render_layer:in render_object:update filter_material:in" do
			if e.render_layer == "opacity" then
				local ro = e.render_object
				local fm = e.filter_material
				local m = fm.main_queue
				ro.mat_mq = m:ptr()
				--Here, we no need to create new material object for this new state, because only main_queue render need this material object
				m:get_material():set_state(check_set_depth_state_as_equal(m:get_state()))
			end
		end
	end
	w:clear "render_object_update"
end