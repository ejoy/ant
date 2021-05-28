local ltask = require "ltask"
local manager = require "ltask.manager"
local ServiceEditor = manager.spawn "editor"

local S = {}

local function writelog()
	local flush
	while true do
		local ti, id, msg, sz = ltask.poplog()
		if ti == nil then
			if flush then
				io.flush()
			end
			break
		end
		local tsec = ti // 100
		local msec = ti % 100
		local t = table.pack(ltask.unpack_remove(msg, sz))
		local str = {}
		for i = 1, t.n do
			str[#str+1] = tostring(t[i])
		end
		local data = string.format("[%s.%02d : %08d]\t%s\n", os.date("%c", tsec), msec, id, table.concat(str, "\t"))
		ltask.send(ServiceEditor, "MESSAGE", "LOG", "SERVER", data)
		io.write(data)
		flush = true
	end
end

local function loop()
	while true do
		writelog()
		ltask.sleep(100)
	end
end

ltask.timeout(0, loop)

function S.quit()
	writelog()
end

return S
