local cpath, repopath = ...

package.path = "engine/?.lua"
package.cpath = cpath

local lfs = require "filesystem.local"
local access = require "vfs.repoaccess"
local thread = require "thread"

local channel = {}
local repo

local function init_channels()
	-- init channels
	channel.req = thread.channel_consume "IOreq"

	local channel_index = {}
	channel.resp = setmetatable({} , channel_index)

	function channel_index:__index(id)
		assert(type(id) == "number")
		local c = assert(thread.channel_produce("IOresp" .. id))
		self[id] = c
		return c
	end

	local channel_user = {}
	channel.user = setmetatable({} , channel_user)

	function channel_user:__index(name)
		local c = assert(thread.channel_produce(name))
		self[name] = c
		return c
	end
end

local function init_repo()
    local path = lfs.path(repopath)
    if not lfs.is_directory(path) then
       error "Not a dir"
    end
    repo = {
        _root = path,
    }
    access.readmount(repo)
end

local function response_id(id, ...)
	if id then
		channel.resp[id](...)
	end
end

local CMD = {}

function CMD.GET(path)
	local rp = access.realpath(repo, path)
	if lfs.exists(rp) then
		return rp:string()
	end
end

function CMD.LIST(path)
	path = path:match "^/?(.-)/?$" .. '/'
	local item = {}
	for filename in pairs(access.list_files(repo, path)) do
		local realpath = access.realpath(repo, path .. filename)
		if realpath then
			item[filename] = not not lfs.is_directory(realpath)
		end
	end
	return item
end

function CMD.TYPE(path)
	local rp = access.realpath(repo, path)
	if lfs.is_directory(rp) then
		return "dir"
	elseif lfs.is_regular_file(rp) then
		return "file"
	end
end

function CMD.REPOPATH()
	return repopath
end

function CMD.MOUNT(name, path)
	access.addmount(repo, name, path)
end

local function dispatch(cmd, id, ...)
    local f = CMD[cmd]
    if not f then
        print("Unsupported command : ", cmd)
        response_id(id)
    else
        response_id(id, f(...))
    end
    return true
end

local function work()
	local c = channel.req
	while true do
		while dispatch(c:bpop()) do end
	end
end

init_channels()
init_repo()
work()
