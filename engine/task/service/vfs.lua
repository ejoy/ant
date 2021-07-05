local ltask = require "ltask"
local exclusive = require "ltask.exclusive"

local thread = require "thread"
local threadid = thread.id
local io_req = thread.channel_produce "IOreq"
local io_resp = thread.channel_consume ("IOresp" .. threadid)

local function npath(path)
	return path:match "^/?(.-)/?$"
end

local queue = {}

local function request(what, ...)
	io_req(what, threadid, ...)
	local token = {}
	queue[#queue+1] = token
	return ltask.wait(token)
end

local function dispatch_response()
	local token = table.remove(queue, 1)
	if token then
		ltask.wakeup(token, io_resp())
		return true
	end
	return false
end

ltask.fork(function ()
	while true do
		if not dispatch_response() then
			exclusive.sleep(1)
			ltask.sleep(0)
		end
	end
end)

local S = {}

function S.GET(path)
	return request("GET", npath(path))
end

function S.LIST(path)
	return request("LIST", npath(path))
end

function S.TYPE(path)
	return request("TYPE", npath(path))
end

function S.REPOPATH()
	return request("REPOPATH")
end

return S
