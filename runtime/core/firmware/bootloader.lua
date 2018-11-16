local repopath, address, port = ...

local fw = require "firmware"
local vfs = assert(fw.loadfile "vfs.lua")()
local repo = vfs.new(repopath)
local function vfs_dofile(path)
    local realpath = repo:realpath(path)
    local f = assert(io.open(realpath))
    local str = f:read 'a'
    f:close()
    return assert(load(str, "@vfs://" .. path))()
end
local vfs = vfs_dofile 'firmware/vfs.lua'
repo = vfs.new(repopath)

local thread = require "thread"
local threadid = thread.id

thread.newchannel "IOreq"
thread.newchannel ("IOresp" .. threadid)

local io_req = thread.channel "IOreq"
local io_resp = thread.channel ("IOresp" .. threadid)

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
	io_req:push {
		repopath = repopath,
		vfspath = repo:realpath("firmware/vfs.lua"),
		address = address,
		port = port,
	}
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
    return f()
end

dofile "main.lua"
