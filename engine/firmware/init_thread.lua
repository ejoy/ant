local thread = require "bee.thread"
local socket = require "bee.socket"
local io_req = thread.channel "IOreq"

local vfs, global = ...

__ANT_RUNTIME__ = package.preload.firmware ~= nil
__ANT_EDITOR__ = global.editor

local fd = socket.fd(global.fd, true)

local function notify()
	local n, err = fd:send "T"
	if n == nil then
		error(string.format("%s: %s", tostring(fd), err))
	elseif n == 0 then
		assert(false, "TODO")
	else
		assert(n == 1)
	end
end

local function call(...)
	local r, _ = thread.rpc_create()
	io_req:push(r, ...)
	notify()
	return thread.rpc_wait(r)
end

local function send(...)
	local r, _ = thread.rpc_create()
	io_req:push(r, ...)
	notify()
end

vfs.call = call
vfs.send = send

function vfs.read(path)
	return call("READ", path)
end

function vfs.readg(path)
	return call("READG", path)
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

function vfs.resource_setting(setting)
	return send("RESOURCE_SETTING", setting)
end

function vfs.version()
	return call("VERSION")
end

if not __ANT_RUNTIME__ then
	function vfs.repopath()
		return call("REPOPATH")
	end
end

if __ANT_EDITOR__ then
	function vfs.mount(path)
		return call("MOUNT", path)
	end
end
