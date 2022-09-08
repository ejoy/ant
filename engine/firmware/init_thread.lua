local thread = require "bee.thread"
local io_req = thread.channel "IOreq"

__ANT_RUNTIME__ = package.preload.firmware ~= nil

local vfs = ...

local function rpc(...)
	local r, _ = thread.rpc_create()
	io_req:push(r, ...)
	return thread.rpc_wait(r)
end

function vfs.realpath(path)
	return rpc("GET", path)
end

function vfs.list(path)
	return rpc("LIST", path)
end

function vfs.type(path)
	return rpc("TYPE", path)
end

function vfs.fetch(path)
	return rpc("FETCH", path)
end

if __ANT_RUNTIME__ then
	function vfs.resource_setting(ext, setting)
		return rpc("RESOURCE_SETTING", ext, setting)
	end
else
	function vfs.repopath()
		return rpc("REPOPATH")
	end
	function vfs.mount(name, path)
		return rpc("MOUNT", name, path)
	end
end
