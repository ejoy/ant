local initargs = ...

__ANT_EDITOR__ = initargs.editor

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
local channelfd = socket.fd(initargs.fd)

local function dofile(path)
	return fastio.loadfile(path)()
end

dofile "engine/log.lua"
package.loaded["vfsrepo"] = dofile "pkg/ant.vfs/vfsrepo.lua"

do
	local vfs = require "vfs"
	local new_tiny = dofile "pkg/ant.vfs/tiny.lua"
	for k, v in pairs(new_tiny(initargs.repopath)) do
		vfs[k] = v
	end
end

local CMD = {}

do
	local new_std = dofile "pkg/ant.vfs/std.lua"
	local repo = new_std {
		rootpath = initargs.repopath,
		nohash = true,
	}
	local function COMPILE(_,_)
		error "resource is not ready."
	end
	local getresource; do
		if initargs.editor then
			function getresource(resource, resource_path)
				local lpath = COMPILE(resource, resource_path)
				if not lpath then
					return
				end
				return repo:build_resource(lpath)
			end
		else
			local resources = {}
			function getresource(resource, resource_path)
				local subrepo = resources[resource]
				if not subrepo then
					local lpath = COMPILE(resource, resource_path)
					if not lpath then
						return
					end
					subrepo = repo:build_resource(lpath)
					resources[resource] = subrepo
				end
				return subrepo
			end
		end
	end
	local function getfile(pathname)
		local file = repo:file(pathname)
		if file then
			return file
		end
		local path, v = repo:valid_path(pathname)
		if not v or not v.resource then
			return
		end
		local subrepo = getresource(v.resource, v.resource_path)
		if not subrepo then
			return
		end
		local subpath = pathname:sub(#path+1)
		return subrepo:file(subpath)
	end
	function CMD.READ(pathname)
		pathname = pathname:gsub("|", "/")
		local file = getfile(pathname)
		if not file then
			return
		end
		if file.path then
			local data = fastio.readall_v(file.path, pathname)
			return data, file.path
		end
		if initargs.editor and file.resource_path then
			local data = fastio.readall_v(file.resource_path, pathname)
			return data, file.resource_path
		end
	end
	function CMD.REALPATH(pathname)
		pathname = pathname:gsub("|", "/")
		local file = getfile(pathname)
		if not file then
			return
		end
		if file.path then
			return file.path
		end
		if initargs.editor and file.resource_path then
			return file.resource_path
		end
	end
	function CMD.LIST(pathname)
		pathname = pathname:gsub("|", "/")
		local file = getfile(pathname)
		if not file then
			return
		end
		if file.resource then
			local subrepo = getresource(file.resource, file.resource_path)
			if not subrepo then
				return
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
		pathname = pathname:gsub("|", "/")
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
		return initargs.repopath
	end
	function CMD.RESOURCE_SETTING(setting)
		require "packagemanager"
		local cr = import_package "ant.compile_resource"
		local vfs = require "vfs"
		local config = cr.init_setting(vfs, setting)
		function COMPILE(vpath, lpath)
			return cr.compile_file(config, vpath, lpath)
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

local function schedule_message() end

local function ltask_init(path, mem)
	assert(fastio.loadlua(mem, path))(true)
	ltask = require "ltask"
	ltask.dispatch(CMD)
	local waitfunc, fd = exclusive.eventinit()
	local ltaskfd = socket.fd(fd)
	-- replace schedule_message
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

function CMD.SWITCH(path, mem)
	while not ltask_ready() do
		exclusive.sleep(1)
	end
	ltask_init(path, mem)
end

function CMD.VERSION()
	return "GAME"
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
