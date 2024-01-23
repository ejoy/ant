local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr  = import_package "ant.asset"

local bgfx 		= require "bgfx"
local math3d 	= require "math3d"

local Q			= world:clibs "render.queue"

local queuemgr	= ecs.require "queue_mgr"

local irender	= ecs.require "ant.render|render_system.render"
local imaterial = ecs.require "ant.asset|material"
local itimer	= ecs.require "ant.timer|timer_system"
local irl		= ecs.require "ant.render|render_layer.render_layer"
local RM        = ecs.require "ant.material|material"

local render_sys= ecs.system "render_system"
local R			= world:clibs "render.render_material"

function render_sys:device_check()
	local caps = bgfx.get_caps()
	if caps.limits.maxTextureSamplers < 16 then
		error(("need device support 16 texture samplers: %d"):format(caps.limits.maxTextureSamplers))
	end

	--TODO: need refactor compute shading code, 8 compute binding resource will be enough
	if caps.limits.maxComputeBindings < 16 then
		error(("need device support 16 compute sampler bindings: %d"):format(caps.limits.maxCounputeBindings))
	end

	if not caps.formats.RGBA8["2D_SRGB"] then
		error("need device framebuffer format RGBA8_SRGB should be supported.")
	end

	if not caps.supported.DRAW_INDIRECT then
		error("need device support draw indirect feature")
	end

	if not (caps.supported.TEXUTRE_COMPARE_ALL or caps.supported.TEXTURE_COMPARE_LEQUAL) then
		error("need device support texture compare")
	end
end

function render_sys:start_frame()
	assetmgr.material_check()
end

function render_sys:component_init()
	for e in w:select "INIT render_object:update filter_material:update" do
		local ro = e.render_object
		ro.rm_idx = R.alloc()

		ro.visible_idx	= Q.alloc()
		ro.cull_idx		= Q.alloc()

		e.filter_material	= e.filter_material or {}
	end
end

local function update_ro(ro, m)
	local vb = m.vb
 	ro.vb_start = vb.start
	ro.vb_num 	= vb.num
	ro.vb_handle= vb.handle

	local vb2 = m.vb2
	if vb2 then
		ro.vb2_start	= vb2.start
		ro.vb2_num		= vb2.num
		ro.vb2_handle	= vb2.handle
	end

	local ib = m.ib
	if ib then
		ro.ib_start = ib.start
		ro.ib_num 	= ib.num
		ro.ib_handle= ib.handle
	end 
end

local RENDER_ARGS = setmetatable({}, {__index = function (t, k)
	local v = {
		queue_index		= queuemgr.queue_index(k),
		material_index	= queuemgr.material_index(k),
	}
	t[k] = v
	return v
end})

local function update_visible_masks(e)
	local vs = e.visible_state
	for qe in w:select "queue_name:in" do
		local qn = qe.queue_name
		
		local index = assert(queuemgr.queue_index(qn))

		local function update_masks(o)
			if o then
				Q.set(o.visible_idx, index, vs[qn])
			end
		end

		update_masks(e.render_object)
		update_masks(e.hitch)
	end
end

function render_sys:entity_init()
	for e in w:select "INIT material_result:in render_object:in filter_material:in view_visible?in render_object_visible?out draw_indirect?in" do
		local mr = e.material_result
		local fm = e.filter_material
		local mi
		if e.draw_indirect and mr.di then
			mi = RM.create_instance(mr.di.object)
		else
			mi = RM.create_instance(mr.object)
		end
		fm["main_queue"] = mi
		local ro = e.render_object
		R.set(ro.rm_idx, queuemgr.material_index "main_queue", mi:ptr())

		e.render_object_visible = e.view_visible
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
		if not queuemgr.has(qn) then
			queuemgr.register_queue(qn)
		end
		RENDER_ARGS[qn].viewid = qe.render_target.viewid
	end

	for e in w:select "INIT render_object filter_result:new" do
		e.filter_result = true
	end

	for e in w:select "INIT visible_state visible_state_changed?out" do
		e.visible_state_changed = true
	end
end

local time_param = math3d.ref(math3d.vector(0.0, 0.0, 0.0, 0.0))
local timepassed = 0.0
local function update_timer_properties()
	timepassed = timepassed + itimer.delta()
	time_param.v = math3d.set_index(time_param, 1, timepassed*0.001, itimer.delta()*0.001)
	imaterial.system_attrib_update("u_time", time_param)
end

local function update_camera_properties()
	if not w:first "camera_changed camera" then
		return
	end

	for qe in w:select "visible queue_name:in camera_ref:in render_target:in" do
		local ce = world:entity(qe.camera_ref, "camera_changed?in camera:in")
		if ce.camera_changed then
			local camera = ce.camera
			bgfx.set_view_transform(qe.render_target.viewid, camera.viewmat, camera.infprojmat)
			if qe.queue_name == "main_queue" then
				w:extend(ce, "scene:in")
				local camerapos = math3d.index(ce.scene.worldmat, 4)
				imaterial.system_attrib_update("u_eyepos", camerapos)

				local f = camera.frustum
				local nn, ff = f.n, f.f
				local inv_nn, inv_ff = 1.0/nn, 1.0/ff
				imaterial.system_attrib_update("u_camera_param", math3d.vector(nn, ff, inv_nn, inv_ff))
			end
		end
	end
end

local function add_render_arg(qe)
	local rt = qe.render_target
	local viewid = rt.viewid

	bgfx.touch(viewid)
	qe.render_args = RENDER_ARGS[qe.queue_name]
end

function render_sys:commit_system_properties()
	update_timer_properties()
	update_camera_properties()
end

function render_sys:follow_scene_update()
	for e in w:select "scene_changed scene:in render_object:update skinning:absent" do
		e.render_object.worldmat = e.scene.worldmat
	end

	for e in w:select "visible_state_changed visible_state:in render_object?update hitch?update" do
		update_visible_masks(e)
	end
end

function render_sys:update_render_args()
	w:clear "render_args"
	if irender.stop_draw() then
		for qe in w:select "swapchain_queue queue_name:in render_target:in render_args:new" do
			add_render_arg(qe)
		end
		return
	end
	for qe in w:select "visible queue_name:in render_target:in render_args:new" do
		add_render_arg(qe)
	end
end

local function clear_filter_material(fm)
	local mm = {}
	for k, m in pairs(fm) do
		if mm[m] == nil then
			mm[m] = true
			m:release()
		end
		fm[k] = nil
	end
end

local function clear_render_object(ro)
	R.dealloc(ro.rm_idx)

	Q.dealloc(ro.visible_idx)
	Q.dealloc(ro.cull_idx)
end

function render_sys:entity_remove()
	for e in w:select "REMOVED render_object:update filter_material:in" do
		clear_filter_material(e.filter_material)

		clear_render_object(e.render_object)
	end
end

local function check_set_depth_state_as_equal(state)
	local ss = bgfx.parse_state(state)
	ss.DEPTH_TEST = "EQUAL"
	local wm = ss.WRITE_MASK
	ss.WRITE_MASK = wm and wm:gsub("Z", "") or "RGBA"
	return bgfx.make_state(ss)
end

function render_sys:update_filter()
	if irender.use_pre_depth() then
		--we should check 'filter_result' here and change the default material
		--because render entity will change it's visible state after it created
		--but not create this new material instance in entity_init stage
		for e in w:select "filter_result visible_state:in render_layer:in render_object:update filter_material:in material:in" do
			if e.visible_state["main_queue"] and irl.is_opacity_layer(e.render_layer) then
				local matres = assetmgr.resource(e.material)
				local ro = e.render_object
				local fm = e.filter_material
				assert(not fm.main_queue:isnull())
				if not matres.fx.setting.no_predepth then
					fm.main_queue:set_state(check_set_depth_state_as_equal(fm.main_queue:get_state()))
				end

				R.set(ro.rm_idx, queuemgr.material_index "main_queue", fm.main_queue:ptr())
			end
		end
	end
end

function render_sys:end_filter()
	w:clear "filter_result"
end