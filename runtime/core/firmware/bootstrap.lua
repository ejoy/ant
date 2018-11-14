local thread = require "thread"

local threadid = thread.id

thread.newchannel "IOreq"
thread.newchannel ("IOresp" .. threadid)

local io_req = thread.channel "IOreq"
local io_resp = thread.channel ("IOresp" .. threadid)

thread.thread (string.format("assert(loadfile(%q))(...)", "firmware/io.lua"), package.searchers[3])

local function vfs_open(repopath, address, port)
	io_req:push {
		repopath = repopath,
		firmware = "firmware",
		address = address,
		port = port,
	}
end

vfs_open("./", "127.0.0.1", 2018)

dofile "firmware/init_thread.lua"
dofile "main.lua"
