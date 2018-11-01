local mgr = require 'debugger.backend.master.mgr'
local thread = require 'thread'

local m = {}

function m.init(io)
    thread.newchannel 'DbgMaster'
    local masterThread = thread.channel 'DbgMaster'
    if not io then
        local type = os.getenv('_DBG_IOTYPE') or 'tcp_server'
        local ioFactory = require('debugger.io.' .. type)
        io = ioFactory('127.0.0.1', os.getenv('_DBG_IOPORT') and tonumber(os.getenv('_DBG_IOPORT')) or 4278)
    end
    mgr.init(io, masterThread)
    return true
end

function m.update()
    while true do
        local quit = mgr.runIdle()
        if quit then
            break
        end
    end
end

return m
