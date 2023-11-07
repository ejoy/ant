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
local vfsrepo = dofile "pkg/ant.vfs/main.lua"

do
	local vfs = require "vfs"
	local repo = vfsrepo.new_tiny(repopath)
	function vfs.realpath(pathname)
		local file = repo:file(pathname)
		if not file then
			return
		end
		if file.path then
			return file.path
		end
	end
	function vfs.list(pathname)
		local file = repo:file(pathname)
		if not file then
			return
		end
		if file.dir then
			local dir = {}
			for _, c in ipairs(file.dir) do
				if c.dir then
					dir[c.name] = { type = "d" }
				elseif c.path then
					dir[c.name] = { type = "f" }
				end
			end
			return dir
		end
	end
	function vfs.type(pathname)
		local file = repo:file(pathname)
		if file then
			if file.dir then
				return "dir"
			elseif file.path then
				return "file"
			end
		end
	end
	function vfs.repopath()
		return repopath
	end
end

local CMD = {}

do
	local resources = {}
	local function COMPILE(_)
		error "resource is not ready."
	end
	local repo = vfsrepo.new_std(repopath, true)
	local function getfile(pathname)
		local file = repo:file(pathname)
		if file then
			return file
		end
		local path, v = repo:valid_path(pathname)
		if not v or not v.resource then
			return
		end
		local subrepo = resources[v.resource]
		if not subrepo then
			local lpath = COMPILE(v.resource_path)
			if not lpath then
				return
			end
			subrepo = repo:build_resource(lpath)
			resources[v.resource] = subrepo
		end
		local subpath = pathname:sub(#path+1)
		return subrepo:file(subpath)
	end
	function CMD.GET(pathname)
		local file = getfile(pathname)
		if not file then
			return
		end
		if file.path then
			return file.path
		end
	end
	function CMD.LIST(pathname)
		local file = getfile(pathname)
		if not file then
			return
		end
		if file.resource then
			local subrepo = resources[file.resource]
			if not subrepo then
				local lpath = COMPILE(file.resource_path)
				if not lpath then
					return
				end
				subrepo = repo:build_resource(lpath)
				resources[file.resource] = subrepo
			end
			file = subrepo:file "/"
		end
		if file.dir then
			local dir = {}
			for _, c in ipairs(file.dir) do
				if c.dir then
					dir[c.name] = { type = "d" }
				elseif c.path then
					dir[c.name] = { type = "f" }
				elseif c.resource then
					dir[c.name] = { type = "r" }
				end
			end
			return dir
		end
	end
	function CMD.TYPE(pathname)
		local file = getfile(pathname)
		if file then
			if file.dir then
				return "dir"
			elseif file.path then
				return "file"
			elseif file.resource then
				return "dir"
			end
		end
	end
	function CMD.REPOPATH()
		return repopath
	end
	function CMD.RESOURCE_SETTING(setting)
		require "packagemanager"
		local cr = import_package "ant.compile_resource"
		local vfs = require "vfs"
		local config = cr.init_setting(vfs, setting)
		function COMPILE(path)
			return cr.compile_file(config, path)
		end
	end
end

local function dispatch(ok, id, cmd, ...)
	if not ok then
		return
	end
	local f = CMD[cmd]
	if not id then
		if not f then
			print("Unsupported command : ", cmd)
		end
		return true
	end
	assert(type(id) == "userdata")
	if not f then
		print("Unsupported command : ", cmd)
		thread.rpc_return(id)
		return true
	end
	thread.rpc_return(id, f(...))
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
