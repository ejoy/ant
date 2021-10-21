return function (_, _)
    local thread = require "bee.thread"
    local io_req  = thread.channel "IOreq"
    local dbg_net = thread.channel "DdgNet"
    local m = {}
    local fsend
    local fclose
    function m.event_in(f)
        fsend = f
    end
    function m.event_close(f)
        fclose = f
    end
    function m.update()
        local ok, _, data = dbg_net:pop()
        if ok then
            fsend(data)
        end
        return true
    end
    function m.send(data)
        io_req:push("SEND", "DBG", data)
    end
    function m.close()
        fclose()
    end
    return m
end
