dofile "libs/init.lua"

local DbgUpdate = require 'new-debugger' .start_all()
local dbgtimer = iup.timer{time=100}
dbgtimer.run = 'YES'
function dbgtimer:action_cb()
	DbgUpdate()
end

pcall(dofile, 'libs/main.lua')
