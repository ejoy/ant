local thread = require "thread"
local io_req = thread.channel_produce "IOreq"

__ANT_RUNTIME__ = package.preload.firmware ~= nil

local vfs = ...

function vfs.realpath(path, hash)
	return io_req:call("GET", path, hash)
end

function vfs.list(path, hash)
	return io_req:call("LIST", path, hash)
end

function vfs.type(path, hash)
	return io_req:call("TYPE", path, hash)
end

if __ANT_RUNTIME__ then
	function vfs.resource(paths)
		return io_req:call("RESOURCE", paths)
	end
else
	function vfs.repopath()
		return io_req:call("REPOPATH")
	end
	function vfs.mount(name, path)
		return io_req:call("MOUNT", name, path)
	end
end
