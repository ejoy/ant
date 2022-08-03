local ecs = ...
local world = ecs.world
local w = world.w

local bgfx 		= require "bgfx"
local math3d 	= require "math3d"
local template	= import_package "ant.general".template
local texmapper	= import_package "ant.asset".textures
local irender	= ecs.import.interface "ant.render|irender"
local ies		= ecs.import.interface "ant.scene|ifilter_state"
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
		pf.filter_type = ies.filter_mask(pf.filter_type)
		pf._DEBUG_excule_type = pf.exclude_type
		pf.exclude_type = pf.exclude_type and ies.filter_mask(pf.exclude_type) or 0
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
    for e in w:select "render_object_update render_object filter_state:in filter_result:new" do
		local matres = imaterial.resource(e, true)
        local fs = e.filter_state
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

local keys = template.keys
local vs_select_cache = template.new (function(a,b) return string.format("hitch_tag %s_visible %s_cull:absent %s render_object:in id:in", a, a, b) end)
local function load_select_key(qn, fn, c)
	local k = keys[qn][fn]
	return c[k]
end

local function transform_find(t, id, ro, mats)
	local c = t[id]
	if c == nil then
		local wm = ro.worldmat
		local stride = math3d.array_size(wm)
		local nummat = #mats
		local num = stride * nummat
		local tid, handle = bgfx.alloc_transform_bulk(num)
		for i=1, nummat do
			local offset = (i-1)*stride
			local r = math3d.array_matrix_ref(handle, stride, offset)
			math3d.mul_array(mats[i], wm, r)
		end
		c = {tid, num, stride}
		t[id] = c
	end
	return c
end

local function submit_hitch_filter(viewid, selkey, qn, groups, transforms)
	for g, mats in pairs(groups) do
		w:group_enable("hitch_tag", g)
		for e in w:select(selkey) do
			local ro = e.render_object
			local tid, num, stride = table.unpack(transforms:find(e.id, ro, mats))
			irender.multi_draw(viewid, ro, e.filter_material[qn], tid, num, stride)
		end
	end
end

local function submit_render_objects(viewid, filter, qn, groups, transforms)
	for _, fn in ipairs(filter) do
		--submit_filter(viewid, load_select_key(qn, fn, select_cache), qn, transforms)
		--submit_hitch_filter(viewid, load_select_key(qn, fn, vs_select_cache), qn, groups, transforms)
	end
end

local group_mt = {__index=function(t, k)
	local tt = {}
	t[k] = tt
	return tt
end}

local queue_material_ids<const> = {
	main_queue = 0,
	pre_depth_queue = 1,
	scene_depth_queue = 2,
	pickup_queue = 3,
	csm1_queue = 4,
	csm2_queue = 5,
	csm3_queue = 6,
	csm4_queue = 7,
}

function render_sys:render_submit()
	-- local groups = setmetatable({}, group_mt)
	-- for e in w:select "view_visible hitch:in scene:in" do
	-- 	local s = e.scene
	-- 	local gid = e.hitch.group
	-- 	if gid ~= 0 then
	-- 		local g = groups[gid]
	-- 		g[#g+1] = s.worldmat
	-- 	end
	-- end

	-- local transforms = {
	-- 	find = transform_find
	-- }

	w:clear "render_args"
	for qe in w:select "visible queue_name:in camera_ref:in render_target:in primitive_filter:in render_args:new" do
		local rt = qe.render_target
		local viewid = rt.viewid

		bgfx.touch(viewid)
		local camera = world:entity(qe.camera_ref).camera
		bgfx.set_view_transform(viewid, camera.viewmat, camera.projmat)

		qe.render_args = {
			visible_id		= w:component_id(qe.queue_name .. "_visible"),
			cull_id			= w:component_id(qe.queue_name .. "_cull"),
			viewid			= viewid,
			queue_index		= queue_material_ids[qe.queue_name] or 0,
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