local repopath, fddata = ...

package.path = "/engine/?.lua"
package.cpath = ""

local fastio = require "fastio"
local vfs = require "vfs"
local thread = require "bee.thread"
local socket = require "bee.socket"
local io_req = thread.channel "IOreq"
thread.setname "ant - IO thread"

local select = require "bee.select"
local selector = select.create()
local SELECT_READ <const> = select.SELECT_READ
local SELECT_WRITE <const> = select.SELECT_WRITE

local quit = false
local channelfd = socket.fd(fddata)

local function dofile(path)
	return assert(fastio.loadfile(path))()
end

dofile "engine/log.lua"

local access = dofile "engine/editor/vfs_access.lua"
dofile "engine/editor/create_repo.lua" (repopath, access)

local function response_id(id, ...)
	if id then
		assert(type(id) == "userdata")
		thread.rpc_return(id, ...)
	end
end

local CMD = {
	GET = vfs.realpath,
	LIST = vfs.list,
	TYPE = vfs.type,
	REPOPATH = vfs.repopath,
	MOUNT = vfs.mount,
}

local function dispatch(ok, id, cmd, ...)
	if not ok then
		return
	end
    local f = CMD[cmd]
    if not f then
        print("Unsupported command : ", cmd)
        response_id(id)
    else
        response_id(id, f(...))
    end
	return true
end

local exclusive = require "ltask.exclusive"
local ltask

local function read_channelfd()
	channelfd:recv()
	if nil == channelfd:recv() then
		selector:event_del(channelfd)
		if not ltask then
			quit = true
		end
		return
	end
	while dispatch(io_req:pop()) do
	end
end

selector:event_add(channelfd, SELECT_READ, read_channelfd)

local function ltask_ready()
	return coroutine.yield() == nil
end

local function schedule_message() end

local function ltask_init()
	assert(fastio.loadfile "engine/task/service/service.lua")(true)
	ltask = require "ltask"
	ltask.dispatch(CMD)
	local waitfunc, fd = exclusive.eventinit()
	local ltaskfd = socket.fd(fd)
	function schedule_message()
		local SCHEDULE_IDLE <const> = 1
		while true do
			local s = ltask.schedule_message()
			if s == SCHEDULE_IDLE then
				break
			end
			coroutine.yield()
		end
	end
	local function read_ltaskfd()
		waitfunc()
		schedule_message()
	end
	selector:event_add(ltaskfd, SELECT_READ, read_ltaskfd)
end

function CMD.SWITCH()
	while not ltask_ready() do
		exclusive.sleep(1)
	end
	ltask_init()
end

function CMD.quit()
	quit = true
end

function CMD.PATCH(code, data)
	local f = load(code)
	f(data)
end

local function work()
	while not quit do
		for func, event in selector:wait() do
			func(event)
		end
		schedule_message()
	end
end

work()
