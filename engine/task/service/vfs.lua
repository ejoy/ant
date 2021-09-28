local ltask = require "ltask"
local exclusive = require "ltask.exclusive"

local thread = require "thread"

local Channel <const> = "VfsService"

thread.newchannel(Channel)
local io_req = thread.channel_produce "IOreq"
local io_resp = thread.channel_consume(Channel)

local queue = {}

local function request(what, ...)
	io_req(Channel, what, ...)
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

function S.GET(path, hash)
	return request("GET", path, hash)
end

function S.LIST(path, hash)
	return request("LIST", path, hash)
end

function S.TYPE(path, hash)
	return request("TYPE", path, hash)
end

function S.RESOURCE(paths)
	return request("RESOURCE", paths)
end

function S.FETCH(path)
	return request("FETCH", path)
end

function S.REPOPATH()
	return request("REPOPATH")
end

return S
