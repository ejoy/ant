local thread = require "thread"

thread.newchannel "errlog"
thread.newchannel "channel"

local err = thread.channel "errlog"
local data = thread.channel "channel"

thread.thread ( [[
	local print = print
	local thread = require "thread"
	print "Hello World"
	local c = thread.channel "channel"
	c:push(1,2,3)
	error ("Exit")
]] , print )

thread.sleep(1)

print(err:pop())
print(data:pop())
