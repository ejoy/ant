local thread = require "thread"
local io_req = thread.channel_produce "IOreq"

local function npath(path)
	return path:match "^/?(.-)/?$"
end

__ANT_RUNTIME__ = package.preload.firmware ~= nil

local vfs = ...

function vfs.realpath(path, hash)
	return io_req:call("GET", npath(path), hash)
end

function vfs.list(path, hash)
	return io_req:call("LIST", npath(path), hash)
end

function vfs.type(path, hash)
	return io_req:call("TYPE", npath(path), hash)
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
		return io_req:call("MOUNT", name, npath(path))
	end
end
