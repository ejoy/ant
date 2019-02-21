local ru = require 'runtime.util'

local dbg = import_package 'ant.debugger'

local thread = require 'thread'
thread.newchannel 'DbgMaster'
thread.newchannel "DdgNet"
local io_req = thread.channel_produce "IOreq"
io_req("SUBSCIBE", "DdgNet", "DBG")
io_req("SEND", "DBG", "")

ru.createThread('debug', [[
    local thread = require "thread"
    local io_req  = thread.channel_produce "IOreq"
    local dbg_net = thread.channel_consume "DdgNet"
    local dbg_io = {}
    function dbg_io:event_in(f)
        self.fsend = f
    end
    function dbg_io:event_close(f)
        self.fclose = f
    end
    function dbg_io:update()
        local ok, cmd, data = dbg_net:pop()
        if ok then
            self.fsend(data)
        end
        return true
    end
    function dbg_io:send(data)
        io_req("SEND", "DBG", data)
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

return dbg.start_worker(arg[1] == '-stopOnEntry')
