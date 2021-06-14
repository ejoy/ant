local config = ...

local vfs = require "vfs"
local thread = require "thread"
local errlog = thread.channel_produce "errlog"
local errthread = thread.thread([[
	-- Error Thread
	local thread = require "thread"
	local err = thread.channel_consume "errlog"
	while true do
		local msg = err()
		if msg == "EXIT" then
			break
		end
		print("ERROR:" .. msg)
	end
]])

local threadid = thread.id

thread.newchannel "IOreq"
thread.newchannel ("IOresp" .. threadid) -- TODO: No need?

local io_req = thread.channel_produce "IOreq"

local firmware_io = vfs.realpath("engine/firmware/io.lua")
thread.thread (([[
    -- IO thread
    local firmware_io = %q
    local function loadfile(path, name)
        local f, err = io.open(path)
        if not f then
            return nil, ('%%s:No such file or directory.'):format(name)
        end
        local str = f:read 'a'
        f:close()
		return load(str, "@/" .. name)
    end
    assert(loadfile(firmware_io, 'engine/firmware/io.lua'))(loadfile)
]]):format(firmware_io))

local function initIOThread()
    config.vfspath = vfs.realpath("engine/firmware/vfs.lua")
	io_req:push(config)
end

initIOThread()
vfs.initfunc "engine/firmware/init_thread.lua"

local function dofile(path)
    local f, err = vfs.loadfile(path)
    if not f then
        error(err)
    end
    errlog:push("EXIT")
    thread.wait(errthread)
    return f()
end

dofile "main.lua"
