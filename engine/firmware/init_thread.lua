local thread = require "bee.thread"
local socket = require "bee.socket"
local io_req = thread.channel "IOreq"

__ANT_RUNTIME__ = package.preload.firmware ~= nil

local vfs, fddata = ...
local fd = socket.fd(fddata)

local function call(...)
	local r, _ = thread.rpc_create()
	io_req:push(r, ...)
	fd:send "T"
	return thread.rpc_wait(r)
end

local function send(...)
	local r, _ = thread.rpc_create()
	io_req:push(r, ...)
	fd:send "T"
end

function vfs.realpath(path)
	return call("GET", path)
end

function vfs.list(path)
	return call("LIST", path)
end

function vfs.type(path)
	return call("TYPE", path)
end

function vfs.fetch(path)
	return call("FETCH", path)
end

function vfs.fetch_begin(path)
	return call("FETCH_BEGIN", path)
end

function vfs.fetch_add(session, path)
	send("FETCH_ADD", session, path)
end

function vfs.fetch_update(session)
	return call("FETCH_UPDATE", session)
end

function vfs.fetch_end(session)
	return call("FETCH_END", session)
end

function vfs.call(...)
	return call(...)
end

function vfs.send(...)
	return send(...)
end

function vfs.switch()
	local servicelua = "/engine/task/service/service.lua"
	send("SWITCH", servicelua, vfs.realpath(servicelua))
end

if __ANT_RUNTIME__ then
	function vfs.resource_setting(ext, setting)
		return call("RESOURCE_SETTING", ext, setting)
	end
else
	function vfs.repopath()
		return call("REPOPATH")
	end
	function vfs.mount(path)
		return call("MOUNT", path)
	end
end
