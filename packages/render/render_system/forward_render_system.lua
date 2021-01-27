local ecs = ...
local world = ecs.world

local bgfx 		= require "bgfx"

local default_comp 	= import_package "ant.general".default

local irender 	= world:interface "ant.render|irender"
local ipf		= world:interface "ant.scene|iprimitive_filter"
local isp		= world:interface "ant.render|system_properties"
local icamera	= world:interface "ant.camera|camera"

local render_sys = ecs.system "forward_render_system"

function render_sys:init()
	local vr = {w=world.args.width,h=world.args.height}
	local camera_eid = icamera.create{
		eyepos  = {0, 0, 0, 1},
		viewdir = {0, 0, 1, 0},
		frustum = default_comp.frustum(vr.w/vr.h),
        name = "default_camera",
	}
	--irender.create_pre_depth_queue(vr, camera_eid)
	irender.create_main_queue(vr, camera_eid)
end

local function update_view_proj(viewid, cameraeid)
	local rc = world[cameraeid]._rendercache
	bgfx.set_view_transform(viewid, rc.viewmat, rc.projmat)
end

function render_sys:render_submit()
	isp.update()
	for _, eid in world:each "render_target" do
		local rq = world[eid]
		if rq.visible then
			local rt = rq.render_target
			local viewid = rt.viewid
			bgfx.touch(viewid)
			update_view_proj(viewid, rq.camera_eid)

			local filter = rq.primitive_filter
			local results = filter.result

			for _, fn in ipairs(filter.filter_order) do
				local result = results[fn]
				if result.sort then
					result:sort()
				end
				for _, item in ipf.iter_target(result) do
					irender.draw(viewid, item)
				end
			end
		end
		
	end
end

