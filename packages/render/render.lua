local ecs = ...
local world = ecs.world

local fbmgr 	= require "framebuffer_mgr"
local bgfx 		= require "bgfx"
local ru 		= require "util"

local math3d	= require "math3d"

local ml = ecs.transform "mesh_loader"

function ml.process(e)
	e.rendermesh = e.mesh
end

local rt = ecs.component "render_target"

function rt:init()
	self.view_mode = self.view_mode or ""

	local viewid = self.viewid
	local fb_idx = self.fb_idx
	if fb_idx then
		fbmgr.bind(viewid, fb_idx)
	else
		self.fb_idx = fbmgr.get_fb_idx(viewid)
	end
	return self
end

function rt:delete()
	fbmgr.unbind(self.viewid)
end

local ct= ecs.transform "camera_transfrom"

function ct.process_prefab(e)
	local lt = e.camera.lock_target
	if lt and e.parent == nil then
		error(string.format("'lock_target' defined in 'camera' component, but 'parent' component not define in entity"))
	end
end

local render_sys = ecs.system "render_system"

local function update_view_proj(viewid, camera)
	local view = math3d.lookto(camera.eyepos, camera.viewdir)
	local proj = math3d.projmat(camera.frustum)
	bgfx.set_view_transform(viewid, view, proj)
end

function render_sys:init()
	ru.create_main_queue(world, {w=world.args.width,h=world.args.height})
end

function render_sys:render_commit()
	local render_properties = world:interface "ant.render|render_properties".data()
	for _, eid in world:each "render_target" do
		local rq = world[eid]
		if rq.visible then
			local rt = rq.render_target
			local viewid = rt.viewid
			ru.update_render_target(viewid, rt)
			update_view_proj(viewid, world[rq.camera_eid].camera)

			local filter = rq.primitive_filter
			local results = filter.result

			local function draw_primitives(result)
				local visibleset = result.visible_set.n and result.visible_set or result
				for i=1, visibleset.n do
					local prim = visibleset[i]
					ru.draw_primitive(viewid, prim, render_properties)
				end
			end

			bgfx.set_view_mode(viewid, rt.view_mode)

			draw_primitives(results.opaticy)
			draw_primitives(results.translucent)
		end
		
	end
end

local mathadapter_util = import_package "ant.math.adapter"
local math3d_adapter = require "math3d.adapter"
mathadapter_util.bind("bgfx", function ()
	bgfx.set_transform = math3d_adapter.matrix(bgfx.set_transform, 1, 1)
	bgfx.set_view_transform = math3d_adapter.matrix(bgfx.set_view_transform, 2, 2)
	bgfx.set_uniform = math3d_adapter.variant(bgfx.set_uniform_matrix, bgfx.set_uniform_vector, 2)
	local idb = bgfx.instance_buffer_metatable()
	idb.pack = math3d_adapter.format(idb.pack, idb.format, 3)
	idb.__call = idb.pack
end)

