local ecs = ...

local key_press = {}
local key_callback
local kb_mb = ecs.world:sub {"keyboard"}

local keyboard = ecs.system "keyboard"

function keyboard:frame_update()
    for _, key, press, status in kb_mb:unpack() do
		if press == 1 or press == 2 then
			key_press[key] = true
		else
			key_press[key] = false
			if key_callback then
				key_callback(key)
			end
		end
	end
end

return {
	key_press = key_press,
	key_callback = function(cb)
		key_callback = cb
	end,
}
