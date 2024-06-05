local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr  = import_package "ant.asset"
local setting		= import_package "ant.settings"
local ENABLE_PRE_DEPTH<const>	= not setting:get "graphic/disable_pre_z"

local L			= import_package "ant.render.core".layout

local serialize = import_package "ant.serialize"

local bgfx 		= require "bgfx"
local math3d 	= require "math3d"

local Q			= world:clibs "render.queue"
local MESH		= world:clibs "render.mesh"

local queuemgr	= ecs.require "queue_mgr"

local irender	= ecs.require "ant.render|render"
local imaterial = ecs.require "ant.render|material"
local ivm		= ecs.require "ant.render|visible_mask"
local imesh		= ecs.require "ant.asset|mesh"
local itimer	= ecs.require "ant.timer|timer_system"
local irl		= ecs.require "ant.render|render_layer.render_layer"
local RM        = ecs.require "ant.material|material"

local render_sys= ecs.system "render_system"
local R			= world:clibs "render.render_material"
local RC		= world:clibs "render.cache"

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

function render_sys:post_init()
	RC.set_queue_type("main_queue", queuemgr.queue_index "main_queue")
	RC.set_queue_type("pre_depth_queue", queuemgr.queue_index "pre_depth_queue")
end

local function update_ro(ro, m)
	local vb = m.vb
	MESH.set(ro.mesh_idx, "vb0", vb.start, vb.num, vb.handle)

	local vb2 = m.vb2
	if vb2 then
		MESH.set(ro.mesh_idx, "vb1", vb2.start, vb2.num, vb2.handle)
	end

	local ib = m.ib
	if ib then
		MESH.set(ro.mesh_idx, "ib", ib.start, ib.num, ib.handle)
	end
end

local RENDER_ARGS = setmetatable({}, {__index = function (t, k)
	local v = {
		queue_index		= queuemgr.queue_index(k),
		material_index	= queuemgr.material_index(k)
	}
	t[k] = v
	return v
end})

local function create_material_instance(e)
	local fs = e.feature_set
	local mr = assetmgr.resource(e.material)
	local mo = fs.DRAW_INDIRECT and assert(mr.di, "use draw_indirect component, but material file not define draw_indirect material") or mr
	return RM.create_instance(mo.object)
end

local function update_default_material_index(e)
	w:extend(e, "material:in feature_set:in filter_material:in")
	local ro = e.render_object
	local mi = create_material_instance(e)
	local midx = queuemgr.default_material_index()
	R.set(ro.rm_idx, midx, mi:ptr())
	e.filter_material.DEFAULT_MATERIAL = mi
	e.filter_material[midx] = mi	-- just make it same with rm_idx data
end

local function check_set_depth_state_as_equal(state)
	local ss = irender.has_depth_test(state)
	if ss and not ss.BLEND then
		ss.DEPTH_TEST = "EQUAL"
		if ss.WRITE_MASK then
			ss.WRITE_MASK = ss.WRITE_MASK:gsub("Z", "")
		end
		return bgfx.make_state(ss)
	end
end

local function check_update_main_queue_material(e)
	--TODO: bug here, when we init with render_layer which is opacity layer, then we changed it as not opacity layer, it will has wrong state
	if ENABLE_PRE_DEPTH and ivm.check(e,"main_queue") and irl.is_opacity_layer(assert(e.render_layer)) then
		w:extend(e, "filter_material:in")
		local fm = e.filter_material
		local mr = assetmgr.resource(e.material)
		local mi = fm.DEFAULT_MATERIAL
		if not mr.fx.setting.no_predepth then
			local ns = check_set_depth_state_as_equal(mi:get_state())
			if ns then
				mi = create_material_instance(e)
				mi:set_state(ns)
			end
		end

		local midx = queuemgr.material_index "main_queue"
		R.set(e.render_object.rm_idx, midx, mi:ptr())
		fm[midx] = mi
	end
end

function render_sys:opt_component_init()
	for e in w:select "INIT feature_set:update" do
		e.feature_set = {}
	end

	for e in w:select "INIT filter_material:update" do
		e.filter_material	= {}
	end
end

function render_sys:component_init()
	for e in w:select "INIT render_object:update" do
		local ro = e.render_object
		ro.rm_idx = R.alloc()

		ro.visible_idx	= Q.alloc()
		ro.cull_idx		= Q.alloc()
		ro.mesh_idx		= MESH.alloc()
	end

	-- The entity created with mesh_result should delete handles by themselves
	-- If entity has mesh, mesh_result must be false
	w:filter("owned_mesh_buffer", "INIT mesh:absent mesh_result", true)

	for e in w:select "INIT mesh:in mesh_result:out" do
		e.mesh_result = assetmgr.resource(e.mesh)
	end
end

local function read_mat_varyings(varyings)
	if varyings then
		if type(varyings) == "string" then
			assert(varyings:sub(1, 1) == "/", "Only support full vfs path")
			varyings = serialize.load(varyings)
		end
		return L.parse_varyings(varyings)
	end
end

local function check_varyings(mesh, material)
	local declname = mesh.vb.declname
	if not declname then
		return 
	end

	if mesh.vb2 then
		declname = ("%s|%s"):format(declname, assert(mesh.vb2.declname))
	end

	local matres = assetmgr.resource(material)
	local varyings = read_mat_varyings(matres.fx.varyings)
	if varyings then
		local inputs = L.parse_varyings(L.varying_inputs(declname))
		for k, v in pairs(varyings) do
			--NOTE: why check "a_" here, because bgfx assume our shader input var must be: a_position|a_texcoord|a_color|a_normal...etc, so only check "a_*" here
			if k:match "a_" then
				local function is_input_equal(lhs, rhs)
					return lhs.type == rhs.type and lhs.bind == rhs.bind
				end
				if not (inputs[k] and is_input_equal(inputs[k], v)) then
					error(("Layout: %s, is not declared or not equal to varyings defined"):format(k))
				end
			end
		end
	end
end

function render_sys:entity_init()
	for e in w:select "INIT render_object:update" do
		--filter_result
		w:extend(e, "filter_result?out")
		e.filter_result = true
		update_default_material_index(e)

		--mesh & material
		w:extend(e, "mesh_result:in")
		update_ro(e.render_object, e.mesh_result)
		check_varyings(e.mesh_result, e.material)

		--visible_masks
		w:extend(e, "visible_masks?update")
		ivm.set_masks(e, e.visible_masks or "main_view", true)
		e.visible_masks = nil	--no longer needed

		--render_layer
		w:extend(e, "render_layer?update")
		local rl = e.render_layer
		if not rl  then
			rl = "opacity"
			e.render_layer = rl
		end
		e.render_object.render_layer = assert(irl.layeridx(rl))

		--render_object_visible
		w:extend(e, "render_object_visible?out view_visible?in")
		e.render_object_visible = e.view_visible

		--filter_material.main_queue
		check_update_main_queue_material(e)
	end

	for qe in w:select "INIT submit_queue queue_name:in render_target:in" do
		local qn = qe.queue_name
		local _ = queuemgr.has(qn) or error(("Invalid queue_name:%s, need register"):format(qn))
		RENDER_ARGS[qn].viewid = qe.render_target.viewid
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
end

function render_sys:update_render_args()
	w:clear "render_args"
	if not irender.stop_draw() then
		for qe in w:select "submit_queue visible queue_name:in render_target:in render_args:new" do
			add_render_arg(qe)
		end
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
	-- the mesh handle with owned_mesh_buffer should delete with entity
	-- otherwise the handles would be managed by asset manager
	for e in w:select "REMOVED owned_mesh_buffer mesh_result:in" do
		imesh.delete_mesh(e.mesh_result)
	end

	for e in w:select "REMOVED render_object:update filter_material:in" do
		clear_filter_material(e.filter_material)

		clear_render_object(e.render_object)
	end
end

function render_sys:end_filter()
	w:clear "filter_result"
end