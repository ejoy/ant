local m = {}

local current_tick = 0
local frames = {}
local free_queue = {}

local function allocqueue()
	local n = #free_queue
	if n > 0 then
		local r = free_queue[n]
		free_queue[n] = nil
		return r
	else
		return {}
	end
end

local function wait(co, timeout)
	local ti = current_tick + timeout
	local q = frames[ti]
	if q == nil then
		q = allocqueue()
		frames[ti] = q
	end
	q[#q + 1] = co
end

local function wakeup(co)
    local ok, res = coroutine.resume(co)
    if not ok then
        io.stderr:write(string.format("Error:\n%s\n%s", res, debug.traceback(co)))
        return
    end
    if coroutine.status(co) == "suspended" then
        wait(co, res)
    end
end

function m.add(f)
    local co = coroutine.create(f)
    wait(co, 1)
end

function m.update(delta)
    for _ = 1, delta do
        current_tick = current_tick + 1
        local q = frames[current_tick]
        if q then
            for i = 1, #q do
                local co = q[i]
                q[i] = nil
                if co then
                    wakeup(co)
                end
            end
            frames[current_tick] = nil
            free_queue[#free_queue + 1] = q
        end
	end
end

function m.wait(timeout)
    coroutine.yield(math.max(math.floor(timeout) or 1, 1))
end

return m
