local ecs = ...
local world = ecs.world

local mouse_callback
local mouse_sync_table
local mouse_mb = world:sub {"mouse"}

local mouse = ecs.system "mouse"

function mouse:frame_update()
	for _, btn, state, x, y in mouse_mb:unpack() do
		if mouse_callback then
			mouse_callback(btn, state, x, y)
		end
	end
	local mouse = world:get_mouse()
	mouse_sync_table.mouse_x = mouse.x
	mouse_sync_table.mouse_y = mouse.y
end

return {
	mouse_sync = function (api)
		mouse_sync_table = api
	end,
	mouse_callback = function(cb)
		mouse_callback = cb
	end,
}
