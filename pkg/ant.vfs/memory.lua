local function new_fs()
	local openfile = io.open
	local fs = {}
	local root = { dir = true }
	local zip = require "zip"

	local function create_dir(path)
		local t = root
		for name in path:gmatch "[^/]+" do
			local current = t
			t = t[name]
			if t == nil then
				t = { dir = true }
				current[name] = t
			elseif not t.dir then
				return
			end
		end
		return t
	end

	local function find_dir(path)
		local t = root
		for name in path:gmatch "[^/]+" do
			t = t[name]
			if t == nil then
				return
			end
		end
		return t
	end

	function fs.update(fullpath, localpath)
		local path, name = fullpath:match "(.-)/([^/]+)$"
		if path == nil then
			return nil, ("Invalid path : " .. fullpath)
		end
		local d = create_dir(path)
		local entry = d[name]
		if not entry then
			local f = openfile(localpath, "rb")
			if not f then
				return nil, ("Can't open : " .. localpath)
			end
			entry = {
				content = f:read "a",
			}
			f:close()
			d[name] = entry
		elseif not entry.content then
			return nil, ("Not a file : " .. fullpath)
		else
			local f = openfile(localpath, "rb")
			if not f then
				return nil, ("Can't open : " .. localpath)
			end
			entry.content = f:read "a"
			f:close()
		end
		return true
	end

	local function fetch(fullpath)
		local path, name = fullpath:match "(.-)/([^/]+)$"
		if path == nil then
			return nil, ("Invalid path : " .. fullpath)
		end
		local d = find_dir(path)
		if d == nil then
			return nil, ("Can't find : " .. fullpath)
		end
		return d, name
	end

	function fs.remove(fullpath)
		local d, name = fetch(fullpath)
		if not d then
			return nil, name
		end
		if d[name] then
			d[name] = nil
		else
			return nil, ("Can't find : " .. fullpath)
		end
		return true
	end

	function fs.read(fullpath)
		fullpath = fullpath:gsub("|", "/")
		local d, name = fetch(fullpath)
		if not d then
			return nil, name
		end
		local e = d[name]
		if not e or not e.content then
			return nil, ("Can't read : " .. fullpath)
		end
		return zip.reader_new(e.content)
	end

	function fs.list(fullpath)
		local d, name = fetch(fullpath)
		if not d then
			return nil, name
		end
		local e = d[name]
		e = e and e.dir
		if not e then
			return nil, ("Not a dir : " .. fullpath)
		end
		local r = {}
		for k,v in pairs(e) do
			r[k] = { type = v.dir and "d" or "f" }
		end
		return r
	end

	function fs.type(path)
		local d, name = fetch(path)
		if not d then
			return nil, name
		end
		local e = d[name]
		if e == nil then
			return nil, "No file : " .. name
		else
			return e.content and "file" or "dir"
		end
	end

	return fs
end

local function init_memory_vfs()
	local ltask = require "ltask"
	local CMD = ltask.dispatch()
	if CMD.MEM_UPDATE then
		return
	end

	local fs = new_fs()

	local CMD_READ = CMD.READ
	local CMD_LIST = CMD.LIST
	local CMD_TYPE = CMD.TYPE

	function CMD.READ(path)
		if CMD_TYPE(path) then
			return CMD_READ(path)
		else
			return fs.read(path)
		end
	end

	function CMD.LIST(path)
		if CMD_TYPE(path) then
			return CMD_LIST(path)
		else
			return fs.list(path)
		end
	end

	function CMD.TYPE(path)
		return CMD_TYPE(path) or fs.type(path)
	end

	function CMD.MEM_UPDATE(path, localpath)
		if CMD_TYPE(path) then
			return nil, ("Can't update file in vfs :" .. path)
		end
		return fs.update(path, localpath)
	end

	function CMD.MEM_REMOVE(path)
		if CMD_TYPE(path) then
			return nil, ("Can't remove file in vfs :" .. path)
		end
		return fs.remove(path)
	end
end

local ltask = require "ltask"

local M = {}

local ServiceIO

function M.init()
	local patch = import_package "ant.general".patch
	ServiceIO = ltask.queryservice "io"
	ltask.call(ServiceIO, "PATCH", patch.patchcode, patch.dumpfuncs(init_memory_vfs))
end

function M.update(path, localpath)
	return ltask.call(ServiceIO, "MEM_UPDATE", path, localpath)
end

function M.remove(path)
	return ltask.call(ServiceIO, "MEM_REMOVE", path)
end

return M