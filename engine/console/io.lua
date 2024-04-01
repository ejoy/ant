local dbg = dofile "/engine/firmware/debugger.lua"
if dbg then
	dbg:event("setThreadName", "Thread: IO")
	dbg:event "wait"
end

local ltask = require "ltask"
local fastio = require "fastio"

local repopath, AntEditor = ...
__ANT_EDITOR__ = AntEditor

--TODO: remove they
require "log"
require "filesystem"

require "packagemanager"

do
	-- first step init vfs.
	local vfs = require "vfs"
	function vfs.type(path)
		assert(path == "/pkg/ant.vfs")
		return "d"
	end
end

local vfsrepo = import_package "ant.vfs"
local tiny_vfs = vfsrepo.new_tiny (repopath)
do
	-- second step init vfs.
	local vfs = require "vfs"
	for k, v in pairs(tiny_vfs) do
		vfs[k] = v
	end
end

local repo = vfsrepo.new_std {
	rootpath = repopath,
	nohash = true,
}

local S = {}

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

function S.READ(pathname)
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

function S.LIST(pathname)
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
				dir[c.name] = "d"
			elseif c.path then
				dir[c.name] = "f"
			elseif c.resource then
				dir[c.name] = "r"
			end
		end
		return dir
	end
end

function S.TYPE(pathname)
	local file = getfile(pathname)
	if file then
		if file.dir then
			return "d"
		elseif file.path then
			return "f"
		elseif file.resource then
			return "d"
		end
	end
end

function S.DIRECTORY(what)
	if what == "external" then
		return repopath ..".app/external/"
	elseif what == "internal" then
		return repopath ..".app/internal/"
	end
end

function S.RESOURCE_SETTING(setting)
	local cr = import_package "ant.compile_resource"
	local config = cr.init_setting(tiny_vfs, setting)
	function COMPILE(vpath, lpath)
		return cr.compile_file(config, vpath, lpath)
	end
end

function S.VERSION()
	return "GAME"
end

function S.PATCH(code, data)
	local func = assert(load(code))
	func(data)
end

function S.quit()
	ltask.quit()
end

local select = require "bee.select"
local selector = select.create()
do
	local socket = require "bee.socket"
	local waitfunc, fd = ltask.eventinit()
	selector:event_add(socket.fd(fd), select.SELECT_READ, waitfunc)
end

ltask.idle_handler(function()
	for func, event in selector:wait() do
		func(event)
	end
end)

return S
