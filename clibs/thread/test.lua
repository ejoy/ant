local thread = require "thread"

thread.newchannel "channel"

local err = thread.channel "errlog"
local data = thread.channel "channel"

thread.thread ( [[
	local print = print
	local thread = require "thread"
	print ("Hello World in thread" , thread.id)
	local c = thread.channel "channel"
	c:push(1,2,3)
	local function err()
		error ("Exit")
	end
	err()
]] , print )

--thread.sleep(1)

print("Error:", err:bpop())
print("Channel:", data:bpop())
print("Main thread id", thread.id)
