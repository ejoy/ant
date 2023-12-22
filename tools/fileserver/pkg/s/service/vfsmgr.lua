local ltask = require "ltask"
local fs = require "bee.filesystem"
local fw = require "bee.filewatch"
local vfsrepo = import_package "ant.vfs"
local cr = import_package "ant.compile_resource"

local ServiceArguments = ltask.queryservice "s|arguments"
local arg = ltask.call(ServiceArguments, "QUERY")
local REPOPATH = fs.absolute(arg[1]):lexically_normal():string()

local new_tiny = import_package "ant.vfs".new_tiny
local tiny_vfs = new_tiny(REPOPATH)

local repo
local compiling = 0
local fswatch = fw.create()
local CacheCompileS = {}
local CacheCompileId = {}

local function split(path)
	local r = {}
	path:gsub("[^/\\]+", function(s)
		r[#r+1] = s
	end)
	return r
end

local function ignore_path(p)
	local l = split(p)
	for i = 1, #l do
		if l[i]:sub(1,1) == "." then
			return true
		end
	end
end

local changed = {}
local changed_mark = {}
local changed_time

local function now()
	local _, t = ltask.now()
	return t * 10
end

local function add_changed(type, lpath)
	local originpath = lpath:string()
	local path = lpath:remove_filename():string()
	if changed_mark[path] then
		return
	end
	print(type, originpath)
	changed_mark[path] = true
	changed[#changed+1] = path
	changed_time = now()
end

local function update_watch()
	while true do
		local type, path = fswatch:select()
		if not type then
			break
		end
		if not ignore_path(path) then
			local lpath = fs.path(path):lexically_normal()
			if type == "modify" then
				if not fs.is_directory(lpath) then
					add_changed(type, lpath)
				end
			else
				add_changed(type, lpath)
			end
		end
	end
end

local function update_vfs()
	if #changed == 0 or compiling > 0 or now() - changed_time <= 1000 then
		return
	end
	print("repo rebuild ...")
	local c = changed
	changed = {}
	changed_mark = {}
	changed_time = nil
	repo:close()
	repo = vfsrepo.new_std {
		rootpath = fs.path(REPOPATH),
	}
	for _, s in pairs(CacheCompileS) do
		s.resource_verify = true
	end
	ltask.multi_wakeup "CHANGEROOT"
	print("repo root:", repo:root())
	print("repo rebuild ok..")
end

do
	print("repo init ...")
	repo = vfsrepo.new_std {
		rootpath = fs.path(REPOPATH),
	}
	if repo == nil then
		error "Create repo failed."
	end
	for _, mount in ipairs(repo:initconfig()) do
		fswatch:add(mount.path)
	end
	print("repo root:", repo:root())
	print("repo init ok.")
	ltask.fork(function ()
		while true do
			update_watch()
			update_vfs()
			ltask.sleep(10)
		end
	end)
end

local S = {}

function S.ROOT()
	print("repo root:", repo:root())
	return repo:root()
end

function S.CHANGEROOT(oldroot)
	while oldroot == repo:root() do
		ltask.multi_wait "CHANGEROOT"
	end
	return repo:root()
end

function S.GET(hash)
	return repo:hash(hash)
end

function S.REALPATH(path)
	local file = repo:file(path)
	if file and file.path then
		return fs.absolute(file.path):string()
	end
	return ''
end

function S.VIRTUALPATH(path)
	local vp = repo:virtualpath(path)
	if vp then
		return vp
	end
	return ''
end

function S.RESOURCE_SETTING(setting)
	local CompileId = CacheCompileId[setting]
	if CompileId == true then
		ltask.wait(setting)
		return CacheCompileId[setting]
	elseif CompileId ~= nil then
		return CompileId
	end
	CacheCompileId[setting] = true
	local config = cr.init_setting(tiny_vfs, setting)
	CompileId = #CacheCompileS + 1
	CacheCompileS[CompileId] = {
		id = CompileId,
		config = config,
		resource_verify = true,
	}
	CacheCompileId[setting] = CompileId
	return CompileId
end

function S.RESOURCE_VERIFY(CompileId)
	local s = CacheCompileS[CompileId]
	if not s.resource_verify then
		return
	end
	compiling = compiling + 1
	s.resource_verify = false
	local names, paths = repo:export_resources()
	for i = 1, #paths do
		local name = names[i]
		cr.verify_file(s.config, name, paths[i])
	end
	compiling = compiling - 1
end

function S.RESOURCE(CompileId, path)
    local s = CacheCompileS[CompileId]
    local file = repo:file(path)
    if not file or not file.resource_path then
        return
    end
	compiling = compiling + 1
    local ok, lpath = pcall(cr.compile_file, s.config, file.resource, file.resource_path)
    if not ok then
        if type(lpath) == "table" then
            print(table.concat(lpath, "\n"))
        else
            print(lpath)
        end
		compiling = compiling - 1
        return
    end
    local hash = repo:build_resource(lpath, path):root()
	compiling = compiling - 1
    return hash
end

return S
