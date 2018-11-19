local thread = require "thread"

thread.newchannel "channel"

local err = thread.channel "errlog"
local data = thread.channel "channel"

local thread1 = thread.thread ( [[
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

print("Error:", err:bpop())
print("Channel:", data:bpop())
print("Main thread id", thread.id)

thread.wait(thread1)

local thread2 = thread.thread [[
	local thread = require "thread"
	print("Sleep 1")
	thread.sleep(1)
	print("Exit")
]]

thread.wait(thread2)

local thread3 = thread.thread [[
	local thread = require "thread"
	local c = thread.channel "channel"
	for i = 1,3 do
		thread.sleep(0.02)
		c:push(i)
	end
]]

for i = 1,10 do
	local ok, v = data:pop(0.01)
	print(i, ok, v)
end

