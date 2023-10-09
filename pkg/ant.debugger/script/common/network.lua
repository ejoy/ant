local function open(_, _)
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
        local ok, new_session, data = dbg_net:pop()
        if ok then
            if session ~= new_session then
                vfs.send("SEND", "DEBUGGER_RESP", "4378", session, write)
                write = ""
                session = new_session
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
        vfs.send("SEND", "DEBUGGER_RESP", "4378", session, data)
    end
    function m.close()
        vfs.send("SEND", "DEBUGGER_RESP", "4378", session)
        write = ""
    end
    return m
end

return open
