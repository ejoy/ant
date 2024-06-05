local ecs 	= ...
local world = ecs.world
local w 	= world.w

local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util

local hwi		= import_package "ant.hwi"

local math3d    = require "math3d"

local irq		= ecs.require "ant.render|renderqueue"
local imaterial	= ecs.require "ant.render|material"
local ivm		= ecs.require "ant.render|visible_mask"

local queuemgr	= ecs.require "queue_mgr"
local sampler	= import_package "ant.render.core".sampler
local layoutmgr = require "vertexlayout_mgr"
local fbmgr		= require "framebuffer_mgr"
local bgfx		= require "bgfx"

----
local COLORS<const> = {
	{1.0, 0.0, 0.0, 1.0},
	{0.0, 1.0, 0.0, 1.0},
	{0.0, 0.0, 1.0, 1.0},
	{0.0, 0.0, 0.0, 1.0},
	{1.0, 1.0, 0.0, 1.0},
	{1.0, 0.0, 1.0, 1.0},
	{0.0, 1.0, 1.0, 1.0},
	{0.5, 0.5, 0.5, 1.0},
	{0.8, 0.8, 0.1, 1.0},
	{0.1, 0.8, 0.1, 1.0},
	{0.1, 0.5, 1.0, 1.0},
	{0.5, 1.0, 0.5, 1.0},
}

local unique_color, unique_name; do
	local idx = 0
	function unique_color()
		idx = idx % #COLORS
		idx = idx + 1
		return COLORS[idx]
	end

	local nidx = 0
	function unique_name()
		local id = idx + 1
		local n = "debug_entity" .. id
		idx = id
		return n
	end
end

local DEBUG_ENTITIES = {}
local ientity 		= ecs.require "ant.entity|entity"
local imesh 		= ecs.require "ant.asset|mesh"
local kbmb 			= world:sub{"keyboard"}

local shadowdebug_sys = ecs.system "shadow_debug_system"

local function debug_viewid(n, after)
	local viewid = hwi.viewid_get(n)
	if nil == viewid then
		viewid = hwi.viewid_generate(n, after)
	end

	return viewid
end

local DEBUG_view = {
	queue = {
		depth = {
			viewid = debug_viewid("shadowdebug_depth", "pre_depth"),
			queue_name = "shadow_debug_depth_queue",
			queue_eid = nil,
		},
		color = {
			viewid = debug_viewid("shadowdebug", "ssao"),
			queue_name = "shadow_debug_queue",
			queue_eid = nil,
		}
	},
	light = {
		perspective_camera = nil,
	},
	drawereid = nil
}

local function update_visible_state(e)
	w:extend(e, "eid:in")
	if e.eid == DEBUG_view.drawereid then
		return
	end

	local function update_queue(whichqueue, matchqueue)
		--only pre_depth_queue render_object will produce shadow
		if ivm.check(e, "pre_depth_queue") then
			local qn = DEBUG_view.queue[whichqueue].queue_name
			ivm.set_masks(e, qn, true)
			w:extend(e, "filter_material:update")
			e.filter_material[qn] = e.filter_material[matchqueue]
		end
	end

	update_queue("depth", "pre_depth_queue")
	update_queue("color", "main_queue")
end

function shadowdebug_sys:init_world()
	--make shadow_debug_queue as main_queue alias name, but with different render queue(different render_target)
	queuemgr.register_queue("shadow_debug_depth_queue",	queuemgr.material_index "pre_depth_queue")
	queuemgr.register_queue("shadow_debug_queue", 		queuemgr.material_index "main_queue")
	local vr = irq.view_rect "main_queue"
	local fbw, fbh = vr.h // 2, vr.h // 2
	local depth_rbidx = fbmgr.create_rb{
		format="D32F", w=fbw, h=fbh, layers=1,
		flags = sampler {
			RT = "RT_ON",
			MIN="POINT",
			MAG="POINT",
			U="CLAMP",
			V="CLAMP",
		},
	}

	local depthfbidx = fbmgr.create{rbidx=depth_rbidx}

	local fbidx = fbmgr.create(
					{rbidx = fbmgr.create_rb{
						format = "RGBA16F", w=fbw, h=fbh, layers=1,
						flags=sampler{
							RT="RT_ON",
							MIN="LINEAR",
							MAG="LINEAR",
							U="CLAMP",
							V="CLAMP",
						}
					}},
					{rbidx = depth_rbidx}
				)

	DEBUG_view.queue.depth.queue_eid = world:create_entity{
		policy = {"ant.render|render_queue"},
		data = {
			render_target = {
				viewid = DEBUG_view.queue.depth.viewid,
				view_rect = {x=0, y=0, w=fbw, h=fbh},
				clear_state = {
					clear = "D",
					depth = 0,
				},
				fb_idx = depthfbidx,
			},
			visible = true,
			camera_ref = irq.camera "csm1_queue",
			submit_queue = true,
			queue_name = "shadow_debug_depth_queue",
		}
	}

	DEBUG_view.queue.color.queue_eid = world:create_entity{
		policy = {
			"ant.render|render_queue",
		},
		data = {
			render_target = {
				viewid = DEBUG_view.queue.color.viewid,
				view_rect = {x=0, y=0, w=fbw, h=fbh},
				clear_state = {
					clear = "C",
					color = 0,
				},
				fb_idx = fbidx,
			},
			visible = true,
			camera_ref = irq.camera "csm1_queue",
			submit_queue = true,
			queue_name = "shadow_debug_queue",
		},
	}

	DEBUG_view.drawereid = world:create_entity{
		policy = {
			"ant.render|simplerender",
		},
		data = {
			mesh_result = imesh.init_mesh(ientity.quad_mesh(mu.rect2ndc({x=0, y=0, w=fbw, h=fbh}, irq.view_rect "main_queue")), true),
			material = "/pkg/ant.resources/materials/texquad.material",
			scene = {},
			render_layer = "translucent",
			on_ready = function (e)
				imaterial.set_property(e, "s_tex", fbmgr.get_rb(fbidx, 1).handle)
			end,
		}
	}

	for e in w:select "render_object" do
		update_visible_state(e)
	end
end

function shadowdebug_sys:entity_init()
	for e in w:select "INIT render_object" do
		update_visible_state(e)
	end
end

local function draw_lines(lines)
	return world:create_entity{
		policy = {"ant.render|simplerender"},
		data = {
			mesh_result = ientity.create_mesh{"p3|c40", lines,},
			material = "/pkg/ant.resources/materials/line.material",
			scene = {},
			render_layer = "translucent",
			visible = true,
		}
	}
end

local function vertex_color(v, c)
	local sv = math3d.serialize(v)
	local sc = math3d.serialize(c)

	return sv:sub(1, 12) .. sc
end

local function draw_box(points, M)
	local s = {}
	for i=1, math3d.array_size(points) do
		local p = math3d.array_index(points, i)
		if M then
			p = math3d.transform(M, p, 1)
		end

		s[#s+1] = vertex_color(p, math3d.vector(1.0, 0.0, 0.0, 1.0))
	end

	world:create_entity{
		policy = {"ant.render|simplerender"},
		data = {
			mesh_result = ientity.create_mesh(
				{"p3|c40", s,},
				{
					0, 4, 1, 5,
					2, 6, 3, 7,
			
					0, 2, 1, 3,
					4, 6, 5, 7,
			
					0, 1, 2, 3,
					4, 5, 6, 7,
				}
			),
			material = "/pkg/ant.resources/materials/line.material",
			scene = {},
			render_layer = "translucent",
			visible = true,
		}
	}
end

local function transform_points(points, M)
	local np = {}
	for i=1, math3d.array_size(points) do
		np[i] = math3d.transform(M, math3d.array_index(points, i), 1)
	end

	return math3d.array_vector(np)
end

local function add_entity(points, c, n)
	local eid = ientity.create_frustum_entity(points, c or unique_color())
	n = n or unique_name()
	DEBUG_ENTITIES[n] = eid
	return eid
end

local function transform_ray(ray, M)
	return {
		o = math3d.transform(ray.o, M, 1),
		d = math3d.transform(ray.d, M, 0)
	}
end

function shadowdebug_sys:data_changed()
	for _, key, press in kbmb:unpack() do
		if key == "B" and press == 0 then
			for k, v in pairs(DEBUG_ENTITIES) do
				w:remove(v)
			end

			local sb = w:first "shadow_bounding:in".shadow_bounding
			add_entity(math3d.aabb_points(sb.PSR),	{0.0, 0.0, 1.0, 1.0})

			if sb.PSC then
				add_entity(math3d.aabb_points(sb.PSC),	{0.0, 1.0, 1.0, 1.0})
			end

			for e in w:select "csm:in camera_ref:in" do
				local ce = world:entity(e.camera_ref, "camera:in scene:in")
				local L2W = ce.scene.worldmat
				if ce.camera.Lv2Ndc then
					add_entity(transform_points(math3d.frustum_points(ce.camera.Lv2Ndc), L2W),	{1.0, 0.0, 0.0, 1.0})
				end

				if ce.camera.sceneaabbLS then
					add_entity(transform_points(math3d.aabb_points(ce.camera.sceneaabbLS), L2W), {0.0, 1.0, 0.0, 1.0})
				end

				if ce.camera.verticesLS then
					add_entity(transform_points(math3d.aabb_points(math3d.minmax(ce.camera.verticesLS)), L2W), {0.0, 1.0, 1.0, 1.0})
				end

				add_entity(transform_points(math3d.frustum_points(ce.camera.viewprojmat), L2W),	{1.0, 1.0, 0.0, 1.0})
			end
		elseif key == 'C' and press == 0 then

		end
	end
end
