require "init_package"
local ltask = require "ltask"
local socket = require "socket"
local protocol = require "protocol"
local convert = require "converdbgpath"
local ServiceDebugListen = ltask.uniqueservice "debug.listen"
local ServiceVfsMgr = ltask.uniqueservice "vfsmgr"
local RuntimeFD, VfsSessionId = ...
local DebuggerFD = ltask.call(ServiceDebugListen, "LISTEN")

local function pathToLocal(path)
    return ltask.call(ServiceVfsMgr, "REALPATH", VfsSessionId, path)
end

local function pathToDA(path)
    return ltask.call(ServiceVfsMgr, "VIRTUALPATH", VfsSessionId, path)
end

local S = {}

function S.MESSAGE(data)
    if data == "" then
        return
    end
    socket.send(DebuggerFD, convert.convertSend(pathToLocal, data))
end

ltask.fork(function ()
    while true do
        local data = socket.recv(DebuggerFD)
        if data == nil then
            break
        end
        local msg = convert.convertRecv(pathToDA, data)
        while msg do
            socket.send(RuntimeFD, protocol.packmessage {"DBG", msg})
            msg = convert.convertRecv(pathToDA, "")
        end
    end
end)

function S.QUIT()
    socket.close(DebuggerFD)
    ltask.quit()
end

return S
