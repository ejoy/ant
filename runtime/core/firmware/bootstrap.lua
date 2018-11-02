local firmware, address, port = ...

-- todo : remove this
dofile "libs/init.lua"

local thread = require "thread"

local threadid = thread.id

thread.newchannel "IOreq"
thread.newchannel ("IOresp" .. threadid)

local io_req = thread.channel "IOreq"
local io_resp = thread.channel ("IOresp" .. threadid)


thread.thread (string.format("dofile %q", firmware .. "/io.lua"))

local vfs = {}

local function npath(path)
	return path:match "^/?(.-)/?$"
end

local init = false
function vfs.open(repopath)
	assert(not init)
	io_req:push {
		repopath = npath(repopath),
		firmware = npath(firmware),
		address = address,
		port = port,
	}
	init = true
end

function vfs.list(path)
	io_req:push("LIST", threadid, npath(path))
	return io_resp:bpop()
end

function vfs.realpath(path)
	io_req:push("GET", threadid, npath(path))
	return io_resp:bpop()
end

function vfs.prefetch(path)
	io_req:push("PREFETCH", npath(path))
end

-- init vfs
package.loaded.vfs = vfs
