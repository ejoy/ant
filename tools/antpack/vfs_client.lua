local thread = require "thread"
local threadid = thread.id
thread.newchannel "IOreq"
thread.newchannel ("IOresp" .. threadid)
local io_req = thread.channel_produce "IOreq"
local io_resp = thread.channel_consume ("IOresp" .. threadid)

local vfs = {}

local function npath(path)
	return path:match "^/?(.-)/?$"
end

function vfs.list(path)
	io_req("LIST", threadid, npath(path))
	return io_resp()
end

function vfs.realpath(path)
	io_req("GET", threadid, npath(path))
	return io_resp()
end

function vfs.fetchall(path)
	io_req("FETCHALL", false, npath(path))
end

function vfs.identity(ext, identity)
	io_req("IDENTITY", ext, identity)
end

local function initialize(config)
    thread.thread [[
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
    ]]
    thread.thread [[
        -- IO thread
        assert(loadfile 'engine/firmware/io.lua')(function(path, name)
            local f, err = io.open(path)
            if not f then
                return nil, ('%%s:No such file or directory.'):format(name)
            end
            local str = f:read 'a'
            f:close()
            return load(str, "@/" .. name)
        end)
    ]]
    config.vfspath = "engine/firmware/vfs.lua"
    io_req:push (config)
    local lfs = require "filesystem.local"
    local repopath = lfs.path(config.repopath) / ".repo"
    for i = 0x00, 0xFF do
        lfs.create_directories(repopath / ("%02x"):format(i))
    end
end

local function prefetch(identity)
    local function getall(path)
        local dir = vfs.list(path)
        if not dir then
            return
        end
        for name, v in pairs(dir) do
            local subpath = path .. "/" .. name
            if v then
                getall(subpath)
            else
                vfs.realpath(subpath)
            end
        end
    end
    vfs.identity(".fx",      identity)
    vfs.identity(".mesh",    identity)
    vfs.identity(".texture", identity)
    vfs.fetchall ''
    getall ''
end

return {
    initialize = initialize,
    prefetch = prefetch,
}
