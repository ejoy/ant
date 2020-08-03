local ecs = ...
local world = ecs.world

local fbmgr 	= require "framebuffer_mgr"
local bgfx 		= require "bgfx"

local math3d	= require "math3d"

local irender = world:interface "ant.render|irender"
local isys_properties = world:interface "ant.render|system_properties"
local imaterial = world:interface "ant.asset|imaterial"
local rt = ecs.transform "render_transform"

local function set_world_matrix(rc)
	bgfx.set_transform(rc.worldmat)
end

local function to_v(t)
	assert(type(t) == "table")
	if t.stage then
		return t
	end
	if type(t[1]) == "number" then
		return #t == 4 and math3d.ref(math3d.vector(t)) or math3d.ref(math3d.matrix(t))
	end
	local res = {}
	for i, v in ipairs(t) do
		if type(v) == "table" then
			res[i] = #v == 4 and math3d.ref(math3d.vector(v)) or math3d.ref(math3d.matrix(v))
		else
			res[i] = v
		end
	end
	return res
end

local function generate_properties(uniforms, properties)
	local new_properties
	properties = properties or {}
	if uniforms and #uniforms > 0 then
		new_properties = {}
		for _, u in ipairs(uniforms) do
			local n = u.name
			local v = properties[n] and to_v(properties[n]) or isys_properties.get(n)
			new_properties[n] = {
				value = v,
				handle = u.handle,
				type = u.type,
				set = imaterial.which_set_func(v),
				ref = true,
			}
		end
	end

	return new_properties
end

function rt.process_entity(e)
	local c = e._cache_prefab
	local rc = e._rendercache
	rc.set_transform= set_world_matrix
	rc.fx 			= c.fx
	rc.properties 	= c.fx and generate_properties(c.fx.uniforms, c.properties) or nil
	rc.state 		= c.state
	rc.vb 			= c.vb
	rc.ib 			= c.ib
end

local rt = ecs.component "render_target"
local irq = world:interface "ant.render|irenderqueue"

function rt:init()
	irq.update_rendertarget(self)
	return self
end

function rt:delete()
	fbmgr.unbind(self.viewid)
end

local render_sys = ecs.system "render_system"

local function update_view_proj(viewid, cameraeid)
	local rc = world[cameraeid]._rendercache
	bgfx.set_view_transform(viewid, rc.viewmat, rc.projmat)
end

function render_sys:init()
	irender.create_main_queue{w=world.args.width,h=world.args.height}
end

function render_sys:render_commit()
	isys_properties.update()
	for _, eid in world:each "render_target" do
		local rq = world[eid]
		if rq.visible then
			local rt = rq.render_target
			local viewid = rt.viewid
			bgfx.touch(viewid)
			update_view_proj(viewid, rq.camera_eid)

			local filter = rq.primitive_filter
			local results = filter.result

			local function draw_items(result)
				local items = result.visible_set
				if items then
					for eid, ri in pairs(items) do
						irender.draw(viewid, ri)
					end
				end  
			end

			for _, fn in ipairs(filter.filter_order) do
				draw_items(results[fn])
			end
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

