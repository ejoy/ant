local thread = require "thread"
local threadid = thread.id
local io_req = thread.channel_produce "IOreq"
local io_resp = thread.channel_consume ("IOresp" .. threadid)

local vfs = {}

local function npath(path)
	return path:match "^/?(.-)/?$"
end

function vfs.list(path)
	io_req("LIST", threadid, npath(path))
	return io_resp()
end

function vfs.realpath(path)
	io_req("GET", threadid, npath(path))
	return io_resp()
end

function vfs.prefetch(path)
	io_req("PREFETCH", npath(path))
end

-- prefectch all dir (path should be a dir)
function vfs.fetchall(path)
	io_req("FETCHALL", false, npath(path))
end

-- return "dir" "file" or nil
function vfs.type(path)
	io_req("TYPE", threadid, npath(path))
	return io_resp()
end

package.loaded.vfs = vfs
