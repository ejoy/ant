-- task manager, binding multiple task coroutines into one mainloop/idle function

local coroutine = coroutine

local task = {}

local tasklist = {}
local tasktraceback = setmetatable({}, {__mode = "k" })

local exit_coroutines = {}
local function idlefunc()
	for index, co in ipairs(tasklist) do
		local succ, status = coroutine.resume(co)
		if not succ then
			local tb = tasktraceback[co]
			if tb then
				tb(co, status)
			else
				io.stderr:write(string.format("Error:\n%s\n%s", status, debug.traceback(co)))
			end
			table.insert(exit_coroutines, index)
		elseif status == "EXIT" then
			table.insert(exit_coroutines, index)
		end
	end
	-- remove exit coroutines
	local n = #exit_coroutines
	if n > 0 then
		local i1 = exit_coroutines[1]
		local i2 = i1 + 1
		local nt = #tasklist
		for i = 1,#exit_coroutines do
			local idx = exit_coroutines[i]
			exit_coroutines[i] = nil
			tasklist[idx] = nil
		end
		while i2 <= nt do
			local v = tasklist[i2]
			if v then
				tasklist[i1] = v
				i1 = i1 + 1
			end
			i2 = i2 + 1
		end
		for i = i1, nt do
			tasklist[i] = nil
		end
		if i1 == 1 then
			-- remove all
			iup.SetIdle(nil)
		end
	end
end

function task.add(f, traceback)
	local n = #tasklist
	if n == 0 then
		iup.SetIdle(idlefunc)
	end
	local co = coroutine.create(
		function()
			f()
			task.exit()
		end)
	tasklist[n+1] = co
	tasktraceback[co] = traceback
end

function task.default_tb(co, status)
	iup.Message("Error", string.format("Error:%s\n%s", status, debug.traceback(co)))
end

function task.safe_loop(f,traceback)
	task.loop(f, traceback or task.default_tb)
end

function task.loop(f, traceback)
	assert(f)
	local n = #tasklist
	if n == 0 then
		iup.SetIdle(idlefunc)        
	end
	local co = coroutine.create(
		function()
			while true do
				f()
				task.yield()
			end
		end)
	tasklist[n+1] = co
	tasktraceback[co] = traceback
end

function task.yield()
	coroutine.yield "YIELD"
end

function task.exit()
	coroutine.yield "EXIT"
end

return task
