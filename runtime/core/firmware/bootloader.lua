local repopath, address, port = ...

local vfs = dofile 'firmware/vfs.lua'
local repo = vfs.new(repopath)
local vfs = dofile(repo:realpath('firmware/vfs.lua'))
local repo = vfs.new(repopath)

local thread = require "thread"
local threadid = thread.id

thread.newchannel "IOreq"
thread.newchannel ("IOresp" .. threadid)

local io_req = thread.channel "IOreq"
local io_resp = thread.channel ("IOresp" .. threadid)

thread.thread (string.format("assert(loadfile(%q))(...)", repo:realpath("firmware/io.lua")), package.searchers[3])

local function vfs_init()
	io_req:push {
		repopath = repopath,
		vfspath = repo:realpath("firmware/vfs.lua"),
		address = address,
		port = port,
	}
end

vfs_init()

local openfile = dofile(repo:realpath("firmware/init_thread.lua"))

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
