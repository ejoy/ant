local ltask = require "ltask"
local fs = require "bee.filesystem"
local fw = require "bee.filewatch"
local repo_new = require "repo".new

local ServiceArguments = ltask.queryservice "s|arguments"
local arg = ltask.call(ServiceArguments, "QUERY")
local REPOPATH = arg[1]

local rebuild = false
local repo
local fswatch = fw.create()

local function split(path)
	local r = {}
	path:string():gsub("[^/\\]+", function(s)
		r[#r+1] = s
	end)
	return r
end

local function compare_path_(al, bl)
	for i = 1, #al do
		if al[i] ~= bl[i] then
			return false
		end
	end
	return true
end

local function compare_path(a, b)
	local al = split(a)
	local bl = split(b)
	if #al > #bl then
		return compare_path_(bl, al) and 1 or 0
	end
	return compare_path_(al, bl) and -1 or 0
end

local function ignore_path(p)
	local l = split(p)
	for i = 1, #l do
		if l[i]:sub(1,1) == "." then
			return true
		end
	end
end

local function watch_add_path(paths, path)
	for i = 1, #paths do
		local status = compare_path(paths[i], path)
		if status == -1 then
			return
		end
		if status == 1 then
			paths[i] = path
			return
		end
		--status == 0
	end
	paths[#paths+1] = path
end

local function update_watch()
	while true do
		local type, path = fswatch:select()
		if not type then
			break
		end
		--if rebuild then
		--	goto continue
		--end
		path = fs.path(path)
		if ignore_path(path) then
			goto continue
		end
		local vpath = repo:virtualpath(path)
		if vpath then
			print('Modify repo', vpath)
			rebuild = true
			goto continue
		end
		::continue::
	end
end

ltask.fork(function ()
	while true do
		update_watch()
		ltask.sleep(10)
	end
end)

local S = {}

function S.ROOT()
	if not repo then
		repo = repo_new(fs.path(REPOPATH))
		if repo == nil then
			error "Create repo failed."
		end
		local paths = {}
		watch_add_path(paths, fs.path(REPOPATH):lexically_normal())
		for _, lpath in pairs(repo._mountpoint) do
			watch_add_path(paths, lpath:lexically_normal())
		end
		for i = 1, #paths do
			local path = paths[i]
			fswatch:add(path:string())
		end
		rebuild = true
	end
	if rebuild then
		print(REPOPATH, "rebuild")
		if fs.is_regular_file(fs.path(REPOPATH) / ".repo" / "root") then
			repo:index()
		else
			repo:rebuild()
		end
		print(REPOPATH, "rebuild finish")
	end
	return repo:root()
end

function S.GET(hash)
	local path = repo:hash(hash)
	if path then
		return path
	end
end

function S.FETCH(path)
	local hashs = repo:fetch(path)
	if hashs then
		return table.concat(hashs, "|")
	end
end

function S.FETCH_PATH(hash, path)
	return repo:fetch_path(hash, path)
end

function S.FETCH_DIR(hash)
	return repo:fetch_dir(hash)
end

function S.BUILD(lpath)
	return repo:build_dir(lpath)
end

function S.REALPATH(path)
	return fs.absolute(repo:realpath(path)):string()
end

function S.VIRTUALPATH(path)
	local vp = repo:virtualpath(fs.relative(fs.path(path)))
	if vp then
		return '/' .. vp
	end
	return ''
end


return S
