local ecs = ...
local world = ecs.world

local mouse_callback
local mouse_sync_table
local mouse_mb = world:sub {"mouse"}

local mouse = ecs.system "mouse"

local mouse_button = {
	LEFT = left,
	RIGHT = right,
}

function mouse:frame_update()
	for _, btn, state, x, y in mouse_mb:unpack() do
		if mouse_callback then
			mouse_callback(btn, state, x, y)
		end
		if state == "UP" or state == "DOWN" then
			local b = mouse_button[btn]
			if b then
				mouse_sync_table[b] = state == "DOWN"
			end
		end
	end
	local mouse = world:get_mouse()
	mouse_sync_table.x = mouse.x
	mouse_sync_table.y = mouse.y
end

return {
	mouse_sync = function (state)
		mouse_sync_table = state
		local mouse = world:get_mouse()
		mouse_sync_table.x = mouse.x
		mouse_sync_table.y = mouse.y
	end,
	mouse_callback = function(cb)
		mouse_callback = cb
	end,
}
