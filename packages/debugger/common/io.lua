return function (_, _)
    local thread = require "thread"
    local io_req  = thread.channel_produce "IOreq"
    local dbg_net = thread.channel_consume "DdgNet"
    local m = {}
    function m:event_in(f)
        self.fsend = f
    end
    function m:event_close(f)
        self.fclose = f
    end
    function m:update()
        local ok, _, data = dbg_net:pop()
        if ok then
            self.fsend(data)
        end
        return true
    end
    function m:send(data)
        io_req("SEND", "DBG", data)
    end
    function m:close()
        self.fclose()
    end
    return m
end
