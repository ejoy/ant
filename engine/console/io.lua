local dbg = dofile "/engine/debugger.lua"
if dbg then
	dbg:event("setThreadName", "Thread: IO")
	dbg:event "wait"
end
local ltask = require "ltask"
local fastio = require "fastio"
local socket = require "bee.socket"
local thread = require "bee.thread"
local select = require "bee.select"
local vfs = require "vfs"

package.path = "/engine/?.lua"
package.cpath = ""
thread.setname "ant - IO thread"

local repopath, AntEditor = ...

__ANT_EDITOR__ = AntEditor

local selector = select.create()
local SELECT_READ <const> = select.SELECT_READ
local SELECT_WRITE <const> = select.SELECT_WRITE

dofile "/engine/log.lua"
package.loaded["vfsrepo"] = dofile "/pkg/ant.vfs/vfsrepo.lua"

local CMD = {}

local new_tiny = dofile "/pkg/ant.vfs/tiny.lua"
for k, v in pairs(new_tiny(repopath)) do
	vfs[k] = v
end

local new_std = dofile "/pkg/ant.vfs/std.lua"
local repo = new_std {
	rootpath = repopath,
	nohash = true,
}

local function COMPILE(_,_)
	error "resource is not ready."
end

local getresource; do
	if __ANT_EDITOR__ then
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
	if __ANT_EDITOR__ and file.resource_path then
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
	if __ANT_EDITOR__ and file.resource_path then
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
	return repopath
end

function CMD.RESOURCE_SETTING(setting)
	require "packagemanager"
	local cr = import_package "ant.compile_resource"
	local config = cr.init_setting(vfs, setting)
	function COMPILE(vpath, lpath)
		return cr.compile_file(config, vpath, lpath)
	end
end

function CMD.VERSION()
	return "GAME"
end

function CMD.quit()
	ltask.quit()
end

function CMD.PATCH(code, data)
	local f = load(code)
	f(data)
end

do
	local waitfunc, fd = ltask.eventinit()
	selector:event_add(socket.fd(fd), SELECT_READ, waitfunc)
end

ltask.idle_handler(function()
	for func, event in selector:wait() do
		func(event)
	end
end)

return CMD
