local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr  = import_package "ant.asset"
local setting		= import_package "ant.settings"
local ENABLE_PRE_DEPTH<const>	= not setting:get "graphic/disable_pre_z"

local L			= import_package "ant.render.core".layout

local aio		= import_package "ant.io"

local bgfx 		= require "bgfx"
local math3d 	= require "math3d"

local Q			= world:clibs "render.queue"

local queuemgr	= ecs.require "queue_mgr"

local irender	= ecs.require "ant.render|render_system.render"
local imaterial = ecs.require "ant.asset|material"
local imesh		= ecs.require "ant.asset|mesh"
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

--[[
about rm_idx/Qidx(queue index): (visible_idx|cull_idx):
	*_idx: all of then are allocated in c file, rm_idx in render_material.c, Qidx in queue.cpp
	rm_idx: it's a handle pointing in a memory allocated in render_material.c, it keep multiple 'material_instance' pointer for rendering.
		one render entity(with render_object entity), can be render in multi queue
		one queue for correspond to some render output
		visible_state indicate this render entity should render in which queues
		ex:
			a simple opaticy render entity's visible_state: main_view|cast_shadow|selectable
			'main_view' mean it should first render in 'pre_depth_queue'(use one special vertex only shader, see depth.lua), than render in 'main_queue'(depth write disable, depth test set to equal)
			it will be submit twice with difference shader
			'material_index' of 'main_queue'  in 'rm_idx' slot is 0, and 'material_index' of 'pre_depth_queue' in 'rm_idx' slot is 1, see queue_mgr.lua

		so, if we create a new queue, and we want to create some entities only render in this queue, we need:
			1. use queuemgr.alloc_material to alloc 'material_index', and use queue_mgr.register, to bind this queue with allocated 'material_index'(if call queuemgr.register without 'material_index', it will use default material index which is 0);
			2. create entity, and specify visible_state with this new queue_name;
			3. if the new queue need special material, we should create a system with update_fitler/update_filter_depend stage, add a new material for this 'material_index' reigter with this queue;
			4. if this queue still need to render in 'main_queue', the 'material_index' register with this queue should use a different 'material_index' with 'main_queue' 'material_index';

	visible_idx|cull_idx: it indicates which queue is visibled/culled.
]]

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
		material_index	= queuemgr.material_index(k)
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

function render_sys:init()
	assert(imaterial.default_material_index() == queuemgr.default_material_index())
end

local function create_material_instance(e)
	--TODO: add render_features flag to replace skinning and draw_indirect component check
	w:extend(e, "draw_indirect?in")
	local mr = assetmgr.resource(e.material)
	if e.draw_indirect then
		local di = mr.di
		if not di then
			error("use draw_indirect component, but material file not define draw_indirect material")
		end

		return RM.create_instance(di.object)
	end
	return RM.create_instance(mr.object)
end

local function update_default_material_index(e)
	local ro = e.render_object
	local mi = create_material_instance(e)
	local midx = queuemgr.default_material_index()
	R.set(ro.rm_idx, midx, mi:ptr())
	e.filter_material.DEFAULT_MATERIAL = mi
	e.filter_material[midx] = mi	-- just make it same with rm_idx data
end

local function check_set_depth_state_as_equal(state)
	local ss = bgfx.parse_state(state)
	ss.DEPTH_TEST = "EQUAL"
	local wm = ss.WRITE_MASK
	ss.WRITE_MASK = wm and wm:gsub("Z", "") or "RGBA"
	return bgfx.make_state(ss)
end

local function check_update_main_queue_material(e)
	w:extend(e, "visible_state:in")
	if ENABLE_PRE_DEPTH and e.visible_state["main_queue"] and irl.is_opacity_layer(assert(e.render_layer)) then
		w:extend(e, "filter_material:in")
		local fm = e.filter_material
		local mr = assetmgr.resource(e.material)
		local mi = fm.DEFAULT_MATERIAL
		if not mr.fx.setting.no_predepth then
			local nmi = create_material_instance(e)
			nmi:set_state(check_set_depth_state_as_equal(mi:get_state()))
			mi = nmi
		end

		local midx = queuemgr.material_index "main_queue"
		R.set(e.render_object.rm_idx, midx, mi:ptr())
		fm[midx] = mi
	end
end


function render_sys:component_init()
	for e in w:select "INIT material:in render_object:update filter_material:update filter_result:new" do
		local ro = e.render_object
		ro.rm_idx = R.alloc()

		ro.visible_idx	= Q.alloc()
		ro.cull_idx		= Q.alloc()

		e.filter_material	= {}

		--filter_material&filter_result
		w:extend(e, "filter_material:in filter_result:new")
		e.filter_result = true
		update_default_material_index(e)
	end

	for e in w:select "INIT mesh:in mesh_result?update" do
		e.mesh_result = assetmgr.resource(e.mesh)
	end

	for e in w:select "INIT simplemesh:update mesh_result?update" do
		e.mesh_result = e.simplemesh
	end
end

local function read_mat_varyings(varyings)
	if varyings then
		if type(varyings) == "string" then
			assert(varyings:sub(1, 1) == "/", "Only support full vfs path")
			local datalist = require "datalist"
			varyings = datalist.parse(aio.readall(varyings))
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
		--mesh & material
		w:extend(e, "mesh_result:in material:in")
		update_ro(e.render_object, e.mesh_result)
		check_varyings(e.mesh_result, e.material)

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

	for qe in w:select "INIT queue_name:in render_target:in" do
		local qn = qe.queue_name
		if not queuemgr.has(qn) then
			queuemgr.register_queue(qn)
		end
		RENDER_ARGS[qn].viewid = qe.render_target.viewid
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
	for e in w:select "REMOVED owned_mesh_buffer simplemesh:in" do
		imesh.delete_mesh(e.simplemesh)
	end

	for e in w:select "REMOVED render_object:update filter_material:in" do
		clear_filter_material(e.filter_material)

		clear_render_object(e.render_object)
	end
end

function render_sys:end_filter()
	w:clear "filter_result"
end