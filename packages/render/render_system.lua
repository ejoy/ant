local ecs = ...
local world = ecs.world

local fbmgr 	= require "framebuffer_mgr"
local bgfx 		= require "bgfx"

local math3d	= require "math3d"

local irender = world:interface "ant.render|irender"
local isys_properties = world:interface "ant.render|system_properties"
local imaterial = world:interface "ant.asset|imaterial"
local rt = ecs.transform "render_transform"

function rt.process_entity(e)
	local c = e._cache_prefab

	local properties
	local uniforms = c.fx.uniforms
	local pp = c.properties or {}
	if uniforms and #uniforms > 0 then
		properties = {}
		for _, u in ipairs(uniforms) do
			local n = u.name
			local v = pp[n] or isys_properties.get(n)
			properties[n] = {
				value=v,
				handle = u.handle,
				type = u.type,
				set = imaterial.which_set_func(v),
				ref=true
			}
		end
	end

	e._rendercache.fx 			= c.fx
	e._rendercache.properties 	= properties
	e._rendercache.state 		= c.state
	e._rendercache.vb 			= c.vb
	e._rendercache.ib 			= c.ib
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

local render_sys = ecs.system "render_system"

local icamera = world:interface "ant.camera|camera"
local function update_view_proj(viewid, cameraeid)
	bgfx.set_view_transform(viewid, icamera.viewmat(cameraeid), icamera.projmat(cameraeid))
end

function render_sys:init()
	irender.create_main_queue{w=world.args.width,h=world.args.height}
end

function render_sys:render_commit()
	for _, eid in world:each "render_target" do
		local rq = world[eid]
		if rq.visible then
			local rt = rq.render_target
			local viewid = rt.viewid
			irender.update_render_target(viewid, rt)
			update_view_proj(viewid, rq.camera_eid)

			local filter = rq.primitive_filter
			local results = filter.result

			bgfx.set_view_mode(viewid, rt.view_mode)

			local function draw_items(result)
				local items = result.visible_set
				if items then
					for eid, ri in pairs(items) do
						irender.draw(viewid, ri)
					end
				end
			end

			draw_items(results.opaticy)
			draw_items(results.translucent)
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

