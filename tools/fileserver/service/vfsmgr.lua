require "init_package"
local ltask = require "ltask"
local fs = require "filesystem.cpp"
local fw = require "filewatch"
local repo_new = require "repo".new

local CACHE = {}
local SESSION = {}
local session_id = 0

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

local function watch_add(repo, repopath)
	local paths = {}
	local watchs = {}
	watch_add_path(paths, repopath)
	for _, lpath in pairs(repo._mountpoint) do
		watch_add_path(paths, lpath)
	end
	for i = 1, #paths do
		local path = paths[i]
		watchs[i] = assert(fw.add(path:string()))
	end
	repo._watchs = watchs
end

local function watch_del(repo)
	local watchs = repo._watchs
	for i = 1, #watchs do
		fw.remove(watchs[i])
	end
end

local function repo_create(repopath)
	repopath = fs.path(repopath)
	local repo = repo_new(repopath)
	if not repo then
		return
	end
	if fs.is_regular_file(repopath / ".repo" / "root") then
		repo:index()
	else
		repo:rebuild()
	end
	watch_add(repo, repopath)
	return repo
end

local function update_watch()
	while true do
		local type, path = fw.select()
		if not type then
			break
		end
		if type == 'error' then
			goto continue
		end
		path = fs.path(path)
		if ignore_path(path) then
			goto continue
		end
		local touch = {}
		for k, repo in pairs(CACHE) do
			local vpath = repo:virtualpath(path)
			if vpath then
				print('Modify repo', k, vpath)
				touch[#touch+1] = k
			end
		end
		for _, k in ipairs(touch) do
			local repo = CACHE[k]
			watch_del(repo)
			CACHE[k] = nil
			repo._ref = repo._ref - 1
			if repo._ref == 0 then
				repo:close()
			end
		end
		::continue::
	end
end

ltask.fork(function ()
	while true do
		update_watch()
		ltask.sleep(100)
	end
end)

local S = {}

function S.ROOT(repopath)
	local repo = CACHE[repopath]
	if not repo then
		repo = repo_create(repopath)
		if repo == nil then
			error "Create repo failed."
		end
		repo._ref = 1
		CACHE[repopath] = repo
	end
	session_id = session_id + 1
	SESSION[session_id] = repo
	repo._ref = repo._ref + 1
	return session_id, repo:root()
end

function S.GET(sid, hash)
	local repo = assert(SESSION[sid], "Need ROOT.")
	local path = repo:hash(hash)
	if path then
		return path:string()
	end
end

function S.FETCH(sid, path)
	local repo = assert(SESSION[sid], "Need ROOT.")
	local hashs = repo:fetch(path)
	if hashs then
		return table.concat(hashs, "|")
	end
end

function S.BUILD(sid, path, lpath)
	local repo = assert(SESSION[sid], "Need ROOT.")
	return repo:build_dir(path, lpath)
end

function S.CLOSE(sid)
	local repo = assert(SESSION[sid], "Need ROOT.")
	repo._ref = repo._ref - 1
	SESSION[sid] = nil
	if repo._ref == 0 then
		repo:close()
	end
end

function S.REALPATH(sid, path)
	local repo = assert(SESSION[sid], "Need ROOT.")
	return fs.absolute(repo:realpath(path)):string()
end


function S.VIRTUALPATH(sid, path)
	local repo = assert(SESSION[sid], "Need ROOT.")
	local vp = repo:virtualpath(fs.relative(fs.path(path)))
	if vp then
		return '/' .. vp
	end
	return ''
end


return S
