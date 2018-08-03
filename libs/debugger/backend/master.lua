local mgr = require 'debugger.backend.master.mgr'
local cdebug = require 'debugger.backend'

local io
local m = {}

function m.init(io_)
    local master = cdebug.start 'master'
    if not master then
        return false
    end
    if io_ then
        io = io_
    else
        local type = os.getenv('_DBG_IOTYPE') or 'tcp_server'
        io = require('debugger.backend.master.io.' .. type)
        io.start('127.0.0.1', os.getenv('_DBG_IOPORT') and tonumber(os.getenv('_DBG_IOPORT')) or 4278)
    end
    mgr.init(io, master)
    return true
end

function m.update()
    if not io.update() then
        return
    end

    while true do
        local quit = mgr.runIdle()
        if quit then
            break
        end
    end
end

return m
