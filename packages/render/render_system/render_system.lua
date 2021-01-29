local ecs = ...
local world = ecs.world

local bgfx 		= require "bgfx"

local irender 	= world:interface "ant.render|irender"
local ipf		= world:interface "ant.scene|iprimitive_filter"
local isp		= world:interface "ant.render|system_properties"

local render_sys = ecs.system "render_system"

local function update_view_proj(viewid, cameraeid)
	local rc = world[cameraeid]._rendercache
	bgfx.set_view_transform(viewid, rc.viewmat, rc.projmat)
end

function render_sys:render_submit()
	isp.update()
	for _, eid in world:each "render_target" do
		local rq = world[eid]
		if rq.visible then
			local viewid = rq.render_target.viewid
			bgfx.touch(viewid)
			update_view_proj(viewid, rq.camera_eid)

			for _, result in ipf.iter_filter(rq.primitive_filter) do
				for _, item in ipf.iter_target(result) do
					irender.draw(viewid, item)
				end
			end
		end
		
	end
end

