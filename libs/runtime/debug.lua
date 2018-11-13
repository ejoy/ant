local ru = require 'runtime.util'

local thread = require 'thread'
thread.newchannel 'DbgMaster'

ru.createThread('debug', [[
    local thread = require "thread"
    thread.newchannel "DdgNet"
    local io_req  = thread.channel "IOreq"
    local dbg_net = thread.channel "DdgNet"
    io_req:push("SUBSCIBE", "DdgNet", "DBG")
    local dbg_io = {}
    function dbg_io:event_in(f)
        self.fsend = f
    end
    function dbg_io:event_close(f)
        self.fclose = f
    end
    function dbg_io:update()
        local ok, cmd, msg = dbg_net:pop()
        if ok then
            self.fsend(msg)
        end
        return true
    end
    function dbg_io:send(data)
        io_req:push("SEND", "DBG", data)
    end
    function dbg_io:close()
        self.fclose()
    end

    local dbg = require 'debugger'
    local dbgupdate = dbg.start_master(dbg_io)
    while true do
        dbgupdate()
    end
]])

local dbg = require 'debugger'
return dbg.start_worker()
