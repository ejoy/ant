local config = ...

local thread = require "thread"
local errlog = thread.channel_produce "errlog"
local errthread = thread.thread([[
	-- Error Thread
	package.searchers[1] = ...
	package.searchers[2] = nil
	local thread = require "thread"
	local err = thread.channel_consume "errlog"
	while true do
		local msg = err()
		if msg == "EXIT" then
			break
		end
		print("ERROR:" .. msg)
	end
]], package.searchers[3])

local fw = require "firmware"
local vfs = assert(fw.loadfile "vfs.lua")()
local repo = vfs.new(config.repopath)
local function vfs_dofile(path)
    local realpath = repo:realpath(path)
    local f = assert(io.open(realpath))
    local str = f:read 'a'
    f:close()
    return assert(load(str, "@vfs://" .. path))()
end

local vfs = vfs_dofile 'firmware/vfs.lua'
repo = vfs.new(config.repopath)

local thread = require "thread"
local threadid = thread.id

thread.newchannel "IOreq"
thread.newchannel ("IOresp" .. threadid)

local io_req = thread.channel_produce "IOreq"
local io_resp = thread.channel_consume ("IOresp" .. threadid)

thread.thread (([[
    -- IO thread
    local firmware_io = %q
	package.searchers[1] = ...
    package.searchers[2] = nil
    local function loadfile(path, name)
        local f, err = io.open(path)
        if not f then
            return nil, ('%s:No such file or directory.'):format(name)
        end
        local str = f:read 'a'
        f:close()
		return load(str, "@vfs://" .. name)
    end
    assert(loadfile(firmware_io, 'firmware/io.lua'))(loadfile)
]]):format(repo:realpath("firmware/io.lua")), package.searchers[3])

local function vfs_init()
    config.vfspath = repo:realpath("firmware/vfs.lua")
	io_req:push(config)
end

vfs_init()

local openfile = vfs_dofile "firmware/init_thread.lua"

local function loadfile(path)
    local f, err = openfile(path)
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@vfs://' .. path)
end

local function dofile(path)
    local f, err = loadfile(path)
    if not f then
        error(err)
    end
    errlog:push("EXIT")
    thread.wait(errthread)
    return f()
end

dofile "main.lua"
