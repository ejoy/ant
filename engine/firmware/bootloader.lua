local config = ...

local _dofile = dofile
function dofile(path)
    local f = assert(io.open(path))
    local str = f:read "a"
    f:close()
    return assert(load(str, "@" .. path))()
end
local i = 1
while true do
    if arg[i] == '-e' then
        i = i + 1
        assert(arg[i], "'-e' needs argument")
        load(arg[i], "=(expr)")()
    elseif arg[i] == nil then
        break
    end
    i = i + 1
end
dofile = _dofile

config.vfspath = "/engine/firmware/vfs.lua"

local boot = require "ltask.bootstrap"
local vfs = require "vfs"
local thread = require "bee.thread"
local socket = require "bee.socket"

thread.newchannel "IOreq"

local s, c = socket.pair()
local io_req = thread.channel "IOreq"
io_req:push(config, nil, socket.dump(s))

local SCRIPT = {"-- IO thread"}
SCRIPT[#SCRIPT+1] = "local PRELOAD = {"
for _, v in ipairs {
    "/engine/firmware/io.lua",
    "/engine/firmware/vfs.lua",
    "/engine/task/service/service.lua",
    "/engine/debugger.lua",
} do
    SCRIPT[#SCRIPT+1] = ("[%q] = %q,"):format(v, vfs.realpath(v))
end
SCRIPT[#SCRIPT+1] = "}"
SCRIPT[#SCRIPT+1] = [[
local function loadfile(path)
    local realpath = PRELOAD[path] or path
    local f, err = io.open(realpath)
    if not f then
        return nil, ('%s:No such file or directory.'):format(path)
    end
    local str = f:read 'a'
    f:close()
    return load(str, "@" .. path)
end
]]
SCRIPT[#SCRIPT+1] = [[
local dbg = assert(loadfile '/engine/debugger.lua')()
if dbg then
    dbg:event("setThreadName", "IO thread")
    dbg:event "wait"
end
]]
SCRIPT[#SCRIPT+1] = [[
local thread = require "bee.thread"
local io_req = thread.channel "IOreq"
]]
SCRIPT[#SCRIPT+1] = "assert(loadfile '/engine/firmware/io.lua')(loadfile, io_req:bpop())"

vfs.iothread = boot.preinit (table.concat(SCRIPT, "\n"))

vfs.initfunc("/engine/firmware/init_thread.lua", socket.dump(c))

local function dofile(path)
    local f, err = vfs.loadfile(path)
    if not f then
        error(err)
    end
    return f()
end
dofile "/main.lua"
