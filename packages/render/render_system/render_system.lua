local ecs = ...
local world = ecs.world
local w = world.w

local bgfx 		= require "bgfx"
local math3d 	= require "math3d"
local texmapper	= import_package "ant.asset".textures
local irender	= ecs.import.interface "ant.render|irender"
local ivs		= ecs.import.interface "ant.scene|ivisible_state"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local itimer	= ecs.import.interface "ant.timer|itimer"
local render_sys = ecs.system "render_system"

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

	for e in w:select "INIT mesh:in render_object:update" do
		update_ro(e.render_object, e.mesh)
	end

	for e in w:select "INIT simplemesh:in render_object:update owned_mesh_buffer?out" do
		local sm = e.simplemesh
		update_ro(e.render_object, e.simplemesh)
		e.owned_mesh_buffer = sm.owned_mesh_buffer
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

function render_sys:commit_system_propertivs()
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
    for e in w:select "render_object_update render_object visible_state:in filter_result:new" do
		local matres = imaterial.resource(e, true)
        local fs = e.visible_state
		local st = matres.fx.setting.surfacetype

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
				local add = ((fs & pf.filter_type) ~= 0) and ((fs & pf.exclude_type) == 0)
				mark_tags(add)
			end
		end
		e.filter_result = true
    end
end

function render_sys:render_submit()
	w:clear "render_args"
	for qe in w:select "visible queue_name:in camera_ref:in render_target:in render_args:new" do
		local rt = qe.render_target
		local viewid = rt.viewid

		bgfx.touch(viewid)
		local ce = world:entity(qe.camera_ref)
		if ce.scene_changed then
			local camera = ce.camera
			bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)
		end

		qe.render_args = {
			visible_id			= w:component_id(qe.queue_name .. "_visible"),
			cull_id				= w:component_id(qe.queue_name .. "_cull"),
			viewid				= viewid,
			queue_material_index= rendercore.queue_material_index(qe.queue_name) or 0,
		}
	end

	rendercore.submit(texmapper, function (gid)
		w:group_enable("hitch_tag", gid)
	end)
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

function s:end_filter()
	if irender.use_pre_depth() then
		for e in w:select "filter_result main_queue_visible opacity render_object:update filter_material:in" do
			local ro = e.render_object
			local fm = e.filter_material
			local m = fm.main_queue
			ro.mat_mq = m:ptr()
			--Here, we no need to create new material object for this new state, because only main_queue render need this material object
			m:get_material():set_state(check_set_depth_state_as_equal(m:get_state()))
		end
	end
	w:clear "render_object_update"
end