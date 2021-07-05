local thread = require "thread"
local threadid = thread.id
thread.newchannel ("IOresp" .. threadid)
local io_req = thread.channel_produce "IOreq"
local io_resp = thread.channel_consume ("IOresp" .. threadid)

local function npath(path)
	return path:match "^/?(.-)/?$"
end

__ANT_RUNTIME__ = package.preload.firmware ~= nil

local vfs = ...

function vfs.realpath(path)
	io_req("GET", threadid, npath(path))
	return io_resp()
end

function vfs.list(path)
	io_req("LIST", threadid, npath(path))
	return io_resp()
end

function vfs.type(path)
	io_req("TYPE", threadid, npath(path))
	return io_resp()
end

if not __ANT_RUNTIME__ then
	function vfs.repopath()
		io_req("REPOPATH", threadid)
		return io_resp()
	end
	function vfs.mount(name, path)
		io_req("MOUNT", threadid, name, npath(path))
		return io_resp()
	end
end
