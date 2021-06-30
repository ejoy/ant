local ltask = require "ltask"
local exclusive = require "ltask.exclusive"

local thread = require "thread"
local threadid = thread.id
local io_req = thread.channel_produce "IOreq"
local io_resp = thread.channel_consume ("IOresp" .. threadid)

local function npath(path)
	return path:match "^/?(.-)/?$"
end

ltask.fork(function ()
	while true do
		exclusive.sleep(1)
		ltask.sleep(0)
	end
end)

local S = {}

function S.get(path)
	io_req("GET", threadid, npath(path))
	return io_resp()
end

function S.quit()
end

return S
