local vfs = require "vfs"
local fastio = require "fastio"

local function readall(path)
	local mem = vfs.read(path) or error(("`read `%s` failed."):format(path))
	return fastio.tostring(mem)
end

local function enable_debugger(servicelua)
	local dbg = debug.getregistry()["lua-debug"]
	if dbg then
		dbg:event("setThreadName", "Thread: Bootstrap")
		return table.concat({
			[[local ltask = require "ltask"]],
			[[local name = ("Service:%d <%s>"):format(ltask.self(), ltask.label() or "unk")]],
			[[assert(loadfile '/engine/firmware/debugger.lua')(): event("setThreadName", name): event "wait"]],
			servicelua,
		}, ";")
	end
	return servicelua
end

local m = {}

function m:start(config)
	local servicepath <const> = "/engine/firmware/ltask_service.lua"
	local servicelua = enable_debugger(readall(servicepath))
	config.root.service_source = servicelua
	config.root.service_chunkname = "@"..servicepath
	config.root.initfunc = readall "/engine/firmware/ltask_initservice.lua"
	config.root_initfunc = [[return loadfile "/engine/firmware/ltask_root.lua"]]

	self._obj = dofile "/engine/firmware/ltask_bootstrap.lua"
	self._ctx = self._obj.start(config)
end

function m:wait()
	self._obj.wait(self._ctx)
end

return m
