local thread = require "bee.thread"
local io_req = thread.channel "IOreq"

__ANT_RUNTIME__ = package.preload.firmware ~= nil

local vfs = ...

function vfs.realpath(path)
	return io_req:call("GET", path)
end

function vfs.list(path)
	return io_req:call("LIST", path)
end

function vfs.type(path)
	return io_req:call("TYPE", path)
end

function vfs.fetch(path)
	return io_req:call("FETCH", path)
end

if __ANT_RUNTIME__ then
	function vfs.resource_setting(ext, setting)
		return io_req:call("RESOURCE_SETTING", ext, setting)
	end
else
	function vfs.repopath()
		return io_req:call("REPOPATH")
	end
	function vfs.mount(name, path)
		return io_req:call("MOUNT", name, path)
	end
end
