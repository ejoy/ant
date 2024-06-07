local co = require "coroutine"

local coroutine_create = co.create
local coroutine_resume = co.resume
local coroutine_close = co.close
local coroutine_yield = co.yield
local coroutine_status = co.status

local coroutine = {}

do -- begin coroutine
	local ltask_coroutines = setmetatable({}, { __mode = "kv" })
	-- true : coroutine
	-- false : suspend
	-- nil : exit

	function coroutine.create(f)
		local co = coroutine_create(f)
		ltask_coroutines[co] = true
		return co
	end
	
	do -- begin coroutine.resume
		local function unlock(co, ...)
			ltask_coroutines[co] = true
			return ...
		end

		local function ltask_yielding(co, ...)
			ltask_coroutines[co] = false
			return unlock(co, coroutine_resume(co, coroutine_yield(...)))
		end

		local function resume(co, ok, tag, ...)
			if not ok then
				return ok, tag, ...
			elseif coroutine_status(co) == "dead" then
				-- the main function exit
				ltask_coroutines[co] = nil
				return true, tag, ...
			elseif tag == "USER" then
				return true, ...
			else
				-- blocked in ltask framework, so raise the yielding message
				return resume(co, ltask_yielding(co, tag, ...))
			end
		end

		function coroutine.resume(co, ...)
			local co_status = ltask_coroutines[co]
			if not co_status then
				if co_status == false then
					-- is running
					return false, "cannot resume a ltask coroutine suspend by ltask framework"
				end
				if coroutine_status(co) == "dead" then
					-- always return false, "cannot resume dead coroutine"
					return coroutine_resume(co, ...)
				else
					return false, "cannot resume none ltask coroutine"
				end
			end
			return resume(co, coroutine_resume(co, ...))
		end	
	end -- end coroutine.resume
	
	function coroutine.status(co)
		local status = ltask_coroutines(co)
		if status == "suspended" then
			if ltask_coroutines[co] == false then
				return "blocked"
			else
				return "suspended"
			end
		else
			return status
		end
	end
	
	function coroutine.yield(...)
		return coroutine_yield("USER", ...)
	end

	do -- begin coroutine.wrap

		local function wrap_co(ok, ...)
			if ok then
				return ...
			else
				error(...)
			end
		end

		function coroutine.wrap(f)
			local co = coroutine.create(function(...)
				return f(...)
			end)
			return function(...)
				return wrap_co(coroutine.resume(co, ...))
			end
		end

	end	-- end coroutine.wrap

	function coroutine.close(co)
		ltask_coroutines[co] = nil
		return coroutine_close(co)
	end
end -- end corotuine

_ENV.coroutine = coroutine

log.debug "replace coroutine with ant.coroutine"

return coroutine
