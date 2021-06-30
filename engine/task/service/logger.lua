local ltask = require "ltask"
local SERVICE_ROOT <const> = 1

local S = {}
local lables = {}

local function querylabel(id)
	local label = lables[id]
	if not label then
		label = ltask.call(SERVICE_ROOT, "label", id)
		lables[id] = label
	end
	return label
end

local LOG

if __ANT_RUNTIME__ then
    local thread = require "thread"
    local IO = thread.channel_produce "IOreq"
    function LOG(data)
        IO("SEND", "LOG", data)
    end
else
    function LOG(data)
        io.write(data)
        io.flush()
    end
end

local function writelog()
	while true do
		local ti, id, msg, sz = ltask.poplog()
		if ti == nil then
			break
		end
		local tsec = ti // 100
		local msec = ti % 100
		local t = table.pack(ltask.unpack_remove(msg, sz))
		local str = {}
		for i = 1, t.n do
			str[#str+1] = tostring(t[i])
		end
		LOG(string.format("[%s.%02d : %-10s]%s\n", os.date('%Y-%m-%d %H:%M:%S', tsec), msec, querylabel(id), table.concat(str, "\t")))
	end
end

ltask.fork(function ()
	while true do
		writelog()
		ltask.sleep(100)
	end
end)

function S.quit()
	writelog()
end

return S
