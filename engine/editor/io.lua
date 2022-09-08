local cpath, repopath = ...

package.path = "engine/?.lua"
package.cpath = cpath

local vfs = require "vfs"
local thread = require "bee.thread"
local io_req = thread.channel "IOreq"
thread.setname "ant - IO thread"

local function loadfile(path)
	local f = io.open(path)
	if not f then
		return nil, path..':No such file or directory.'
	end
	local str = f:read 'a'
	f:close()
	return load(str, "@" .. path)
end

local function dofile(path)
	return assert(loadfile(path))()
end

dofile "engine/common/log.lua"

local access = dofile "engine/vfs/repoaccess.lua"
dofile "engine/editor/create_repo.lua" (repopath, access)

local function response_id(id, ...)
	if id then
		assert(type(id) == "userdata")
		thread.rpc_return(id, ...)
	end
end

local CMD = {
	GET = vfs.realpath,
	LIST = vfs.list,
	TYPE = vfs.type,
	REPOPATH = vfs.repopath,
	MOUNT = vfs.mount,
	FETCH = function() end,
}

local S_CMD = {}
for k, f in pairs(CMD) do
	S_CMD[k] = function (id, ...)
		response_id(id, f(...))
	end
end
for k, f in pairs(S_CMD) do
	CMD["S_"..k] = f
end

local function dispatch(ok, id, cmd, ...)
	if not ok then
		return
	end
    local f = CMD[cmd]
    if not f then
        print("Unsupported command : ", cmd)
        response_id(id)
    else
        response_id(id, f(...))
    end
	return true
end

local ltask

local exclusive = require "ltask.exclusive"

local function ltask_ready()
	return coroutine.yield() == nil
end

local function ltask_update()
	if ltask == nil then
		assert(loadfile "engine/task/service/service.lua")(true)
		ltask = require "ltask"
		ltask.dispatch(CMD)
	end
	local SCHEDULE_IDLE <const> = 1
	local SCHEDULE_QUIT <const> = 2
	local SCHEDULE_SUCCESS <const> = 3
	while true do
		local s = ltask.schedule_message()
		if s == SCHEDULE_QUIT then
			ltask.log "${quit}"
			return
		end
		if s == SCHEDULE_IDLE then
			break
		end
		coroutine.yield()
	end
end

local function work()
	while true do
		while dispatch(io_req:pop()) do
		end
		if ltask_ready() then
			ltask_update()
		end
		exclusive.sleep(1)
	end
end

work()
