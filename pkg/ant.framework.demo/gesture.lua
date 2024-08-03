local ecs = ...
local world = ecs.world

local gesture_callback = {}

local gesture_mb = world:sub { "gesture" }

local gesture = ecs.system "gesture"

function gesture:frame_update()
	for _, what, e in gesture_mb:unpack() do
		local cb = gesture_callback[what]
		if cb then
			cb(e)
		end
	end
end

return {
	listen = function(msg, cb)
		gesture_callback[msg] = cb
	end,
}
