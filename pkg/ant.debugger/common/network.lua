return function (_, _)
    local vfs = require "vfs"
    local thread = require "bee.thread"
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
        vfs.send("SEND", "DBG", data)
    end
    function m.close()
        fclose()
    end
    return m
end
