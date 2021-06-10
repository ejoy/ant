local thread = require "thread"
local threadid = thread.id
-- main thread id is 0
if threadid ~= 0 then
    thread.newchannel ("IOresp" .. threadid)
end
local io_req = thread.channel_produce "IOreq"
local io_resp = thread.channel_consume ("IOresp" .. threadid)

local function npath(path)
	return path:match "^/?(.-)/?$"
end

local vfs = require "vfs"
function vfs.realpath(path)
	io_req("GET", threadid, npath(path))
	return io_resp()
end
