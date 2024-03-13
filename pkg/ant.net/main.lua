local ltask = require "ltask"
local network = require "network"
local patch = import_package "ant.general".patch

local pkg_name <const> = "ant.net"

local find_upvalues = patch.find_upvalues
local new_network = network.new

local function register(uv, cmd)
	local response_id = uv.response_id
	local response_err = uv.response_err
	local ltask = assert(uv.ltask)	-- use ltask from upvalues
	local CMD = ltask.dispatch()
	for k,v in pairs(cmd) do
		if CMD[k] then
			error("CMD ["..k.."] exist")
		end
		CMD[k] = v
	end
end

local function check_init(uv)
	local ltask = assert(uv.ltask)
	local CMD = ltask.dispatch()
	local f = CMD.NETWORK_PKG
	if not f then
		return
	end
	assert(f() == pkg_name)
	return true
end

local function init_network()
	local uv = find_upvalues "/io.lua"
	if check_init(uv) then
		return
	end
	local selector = assert(uv.selector)
	local net = new_network(selector)
	local CMD = {
		NETWORK_PKG = function() return pkg_name end,
		NETWORK_LISTEN = assert(net.listen),
		NETWORK_CONNECT = assert(net.connect),
		NETWORK_ACCEPT = assert(net.accept),
		NETWORK_RECV = assert(net.recv),
		NETWORK_SEND = assert(net.send),
		NETWORK_CLOSE = assert(net.close),
	}

	register(uv, CMD)
end

local function init()
	local ServiceIO = ltask.queryservice "io"
	ltask.call(ServiceIO, "PATCH", patch.patchcode, patch.dumpfuncs(init_network))
end

local function api(name)
	local ServiceIO = ltask.queryservice "io"
	local pname = "NETWORK_" .. name:upper()
	return function (...)
		return ltask.call(ServiceIO, pname, ...)
	end
end

init()

return {
	listen = api "listen",
	connect = api "connect",
	accept = api "accept",
	recv = api "recv",
	send = api "send",
	close = api "close",
}
