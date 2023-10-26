local ltask = require "ltask"
local fs = require "bee.filesystem"
local fw = require "bee.filewatch"
local new_repo = require "repo"

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

local function update_watch()
	local changed = {}
	local mark = {}
	local function add_changed(type, lpath)
		local originpath = lpath:string()
		local path = lpath:remove_filename():string()
		if mark[path] then
			return
		end
		print(type, originpath)
		mark[path] = true
		changed[#changed+1] = path
	end
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
	if #changed > 0 then
		print("repo rebuild ...")
		repo:rebuild(changed)
		for _, s in pairs(CacheCompileS) do
			s.resource = {}
		end
		print("repo rebuild ok..")
	end
end

do
	print("repo init ...")
	repo = new_repo(fs.path(REPOPATH))
	if repo == nil then
		error "Create repo failed."
	end
	for _, lpath in ipairs(repo:mountlapth()) do
		fswatch:add(lpath:string())
	end
	print("repo init ok.")
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
	return repo:hash(hash)
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
    local hash = repo:build_resource(lpath, path)
    s.resource[path] = hash
    return hash
end

return S
