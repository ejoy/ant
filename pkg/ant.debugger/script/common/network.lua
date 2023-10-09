local function open(port)
    local vfs = require "vfs"
    local thread = require "bee.thread"
    local dbg_net = thread.channel "DdgNet"
    local m = {}
    local session
    local fsend
    local fclose
    local write = ""
    function m.event_in(f)
        fsend = f
    end
    function m.event_close(f)
        fclose = f
    end
    function m.update()
        local ok, _, new_session, data = dbg_net:pop()
        if ok then
            if session ~= new_session then
                session = new_session
                if write ~= "" then
                    vfs.send("SEND", "DEBUGGER_RESP", port, session, write)
                    write = ""
                end
            end
            if data == nil then
                fclose()
            else
                fsend(data)
            end
        end
        return true
    end
    function m.send(data)
        if not session then
            write = write .. data
            return
        end
        vfs.send("SEND", "DEBUGGER_RESP", port, session, data)
    end
    function m.close()
        vfs.send("SEND", "DEBUGGER_RESP", port, session)
        write = ""
    end
    return m
end

return open
