local thread = require "thread"

local threadid = thread.id

thread.newchannel "IOreq"
thread.newchannel ("IOresp" .. threadid)

local io_req = thread.channel "IOreq"
local io_resp = thread.channel ("IOresp" .. threadid)

thread.thread (string.format("assert(loadfile(%q))(...)", "firmware/io.lua"), package.searchers[3])

local function vfs_init(repopath, address, port)
	io_req:push {
		repopath = repopath,
		vfspath = "firmware/vfs.lua",
		address = address,
		port = port,
	}
end

local function vfs_get(path)
	io_req:push("GET", threadid, path)
	return io_resp:bpop()
end

local function vfs_list(path)
	io_req:push("LIST", threadid, path)
	return io_resp:bpop()
end

local function vfs_getdir(path)
    local l = vfs_list(path)
    for name, type in pairs(l) do
        if type == false then
            vfs_get(path .. '/' .. name)
        elseif type == true then
            vfs_getdir(path .. '/' .. name)
        end
    end
end

local function vfs_fetchall(path)
    io_req:push("FETCHALL", false, path)
    vfs_getdir(path)
end

local function vfs_exit()
	io_req:push("EXIT", threadid)
	return io_resp:bpop()
end

vfs_init("./", "127.0.0.1", 2018)
vfs_fetchall('firmware')
local bootstrap2 = vfs_get('firmware/bootstrap2.lua')
vfs_exit()
thread.reset()

dofile(bootstrap2)
