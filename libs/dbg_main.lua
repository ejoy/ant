package.cpath = "./clibs/?.dll;./bin/?.dll"
package.path = "./libs/?.lua;./libs/?/?.lua"

local dbg = require 'new-debugger'
local dbgupdate = dbg.start_all(true)
local dbgtimer = iup.timer{time=100}
dbgtimer.run = 'YES'
function dbgtimer:action_cb()
	dbgupdate()
end

pcall(dofile, 'libs/main.lua')
