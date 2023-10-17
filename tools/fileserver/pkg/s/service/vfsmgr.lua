local ltask = require "ltask"
local fs = require "bee.filesystem"
local fw = require "bee.filewatch"
local repo_new = require "repo".new

local ServiceArguments = ltask.queryservice "s|arguments"
local arg = ltask.call(ServiceArguments, "QUERY")
local REPOPATH = arg[1]

local repo
local fswatch = fw.create()

local CacheCompileId = {}
local CacheCompileS = {}

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
	for _, s in pairs(CacheCompileS) do
		s.resource = {}
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
		if not ignore_path(path) then
			print(type, path)
			rebuild = true
		end
	end
	if rebuild then
		rebuild_repo()
	end
end

do
	repo = repo_new(fs.path(REPOPATH))
	if repo == nil then
		error "Create repo failed."
	end
	for _, lpath in pairs(repo._mountpoint) do
		fswatch:add(lpath:string())
	end
	rebuild_repo()
	ltask.fork(function ()
		while true do
			update_watch()
			ltask.sleep(10)
		end
	end)
end

local S = {}

function S.ROOT()
	return repo:root()
end

function S.GET(hash)
	local path = repo:hash(hash)
	if path then
		return path
	end
end

function S.REALPATH(path)
	local rp = repo:realpath(path)
	if rp then
		return fs.absolute(rp):string()
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

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local function stringify(t)
    local s = {}
    for k, v in sortpairs(t) do
        s[#s+1] = k.."="..tostring(v)
    end
    return table.concat(s, "&")
end

function S.RESOURCE_SETTING(setting)
    local key = stringify(setting)
    local CompileId = CacheCompileId[key]
    if CompileId == true then
        ltask.wait(key)
        return CacheCompileS[CacheCompileId[key]]
    elseif CompileId ~= nil then
        return CacheCompileS[CompileId]
    end
    CacheCompileId[key] = true
    CompileId = ltask.spawn("ant.compile_resource|compile", REPOPATH)
    ltask.call(CompileId, "SETTING", setting)
    CacheCompileId[key] = CompileId
    local s = {
        id = CompileId,
        resource = {},
    }
    CacheCompileS[CompileId] = s
    ltask.wakeup(key)
    return s
end

function S.RESOURCE(CompileId, path)
    local s = CacheCompileS[CompileId]
    local ok, lpath = pcall(ltask.call, s.id, "COMPILE", path)
    if not ok then
        if type(lpath) == "table" then
            print(table.concat(lpath, "\n"))
        else
            print(lpath)
        end
        s.resource[path] = nil
        return
    end
    local hash = repo:build_dir(lpath)
    s.resource[path] = hash
    return hash
end

return S
