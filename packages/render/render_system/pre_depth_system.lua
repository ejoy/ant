local ecs = ...
local world = ecs.world
local irq = world:interface "ant.render|irenderqueue"

local pd_sys = ecs.system "pre_depth_system"
local pd_mbs = {}
function pd_sys:post_init()
	local pd_eid = world:singleton_entity_id "pre_depth_queue"
	if pd_eid == nil then
		return
	end

	local mq_eid = world:singleton_entity_id "main_queue"
	local mq = world[mq_eid]
	local callbacks = {
		view_rect = function (m)
			local vr = mq.render_target.view_rect
			irq.set_view_rect(pd_eid, vr)
		end,
		camera_eid = function (m)
			irq.set_camera(pd_eid, mq.camera_eid)
		end,
		framebuffer = function (m)
			error "not implement"
		end,
	}

	for n, cb in pairs(callbacks) do
		pd_mbs[n] = {
			mb = world:sub{"component_changed", n, mq_eid},
			cb = cb
		}
	end
end
function pd_sys:render_preprocess()
	for _, d in pairs(pd_mbs) do
		local cb = d.cb
		for msg in d.mb:each() do
			cb(msg)
		end
	end
end