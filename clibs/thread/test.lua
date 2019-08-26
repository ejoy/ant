local thread = require "thread"

thread.newchannel "channel"

local err = thread.channel_consume "errlog"
local data = thread.channel_consume "channel"

local thread1 = thread.thread ( [[
	local print = (...)
	local thread = require "thread"
	print ("Hello World in thread" , thread.id)
	local c = thread.channel_produce "channel"
	c(1,2,3)	-- c:push(1,2,3)
	local function err()
		error ("Exit")
	end
	err()
]] , print )

print("Error:", err())	-- err:bpop()
print("Channel:", data())
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
	local c = thread.channel_produce "channel"
	local err = thread.channel_produce "errlog"
	for i = 1,5 do
		thread.sleep(0.02)
		c(i)	-- c: push(i)
		err("THREAD"..thread.id, "PUSH", i)
	end
]]

local consumer = [[
	local thread = require "thread"
	local data = thread.channel_consume "channel"
	local err = thread.channel_produce "errlog"
	for i = 1,20 do
		local ok, v = data:pop()
		thread.sleep(0.01)
		if ok then
			err("THREAD" .. thread.id, "POP", v)
		end
	end
]]

local c1 = thread.thread(consumer)
local c2 = thread.thread(consumer)

thread.wait(c1)
thread.wait(c2)

while true do
	local function output(ok, ...)
		print(...)
		return ok
	end
	if not output(err:pop()) then
		break
	end
end

-- test fork

local function fork()
	print "Fork : run (Sleep 1)"
	thread.sleep(1)
	print "Fork : end"
	return "Return to main thread"
end

local run_in_main = [[
	local thread = require "thread"
	print("Main : run (Sleep 2)")
	thread.sleep(2)
	print("Main : end")
]]

print(thread.fork(fork, run_in_main))
