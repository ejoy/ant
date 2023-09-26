local ltask = require "ltask"
local fs = require "bee.filesystem"
local fw = require "bee.filewatch"
local repo_new = require "repo".new

local ServiceArguments = ltask.queryservice "s|arguments"
local arg = ltask.call(ServiceArguments, "QUERY")
local REPOPATH = arg[1]

local repo
local fswatch = fw.create()

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

local function rebuild_repo()
	print("rebuild start")
	if fs.is_regular_file(fs.path(REPOPATH) / ".repo" / "root") then
		repo:index()
	else
		repo:rebuild()
	end
	print("rebuild finish")
end

local function update_watch()
	local rebuild = false
	while true do
		local type, path = fswatch:select()
		if not type then
			break
		end
		if not rebuild and ignore_path(path) then
			rebuild = true
		end
	end
	if rebuild then
		rebuild_repo()
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
		for _, lpath in pairs(repo._mountpoint) do
			fswatch:add(lpath:lexically_normal():string())
		end
		rebuild_repo()
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
