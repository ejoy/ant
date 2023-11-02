local repopath, fddata = ...

package.path = "/engine/?.lua"
package.cpath = ""

local fastio = require "fastio"
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
package.loaded["vfsrepo"] = dofile "pkg/ant.vfs/vfsrepo.lua"
local new_repo = dofile "pkg/ant.vfs/main.lua"
local repo = new_repo(repopath)

local function response_id(id, ...)
	if id then
		assert(type(id) == "userdata")
		thread.rpc_return(id, ...)
	end
end

local CMD = {}

function CMD.GET(pathname)
	local file = repo:file(pathname)
	if not file then
		return nil, "Not exist<1> " .. pathname
	end
	if not file.path then
		if file.resource_path then
			return file.resource_path
		end
		return nil, "Not exist<2> " .. pathname
	end
	return file.path
end

function CMD.LIST(pathname)
	local file = repo:file(pathname)
	if file and file.dir then
		local dir = {}
		for _, c in ipairs(file.dir) do
			if c.dir then
				dir[c.name] = {
					type = "d",
					hash = c.hash,
				}
			elseif c.path then
				dir[c.name] = {
					type = "f",
					hash = c.hash,
				}
			elseif c.resource then
				dir[c.name] = {
					type = "r",
				}
			end
		end
		return dir
	end
end

function CMD.TYPE(pathname)
	local file = repo:file(pathname)
	if file then
		if file.dir then
			return "dir"
		elseif file.path then
			return "file"
		end
	end
end

function CMD.REPOPATH()
	return repopath
end

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

local function ltask_init()
	assert(fastio.loadfile "engine/task/service/service.lua")(true)
	ltask = require "ltask"
	ltask.dispatch(CMD)
	local waitfunc, fd = exclusive.eventinit()
	local ltaskfd = socket.fd(fd)
	local function read_ltaskfd()
		waitfunc()
		local SCHEDULE_IDLE <const> = 1
		while true do
			local s = ltask.schedule_message()
			if s == SCHEDULE_IDLE then
				break
			end
			coroutine.yield()
		end
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

local function work()
	while not quit do
		for func in selector:wait() do
			func()
		end
	end
end

work()
