local nt = require "backend.master.named_thread"

return function (error_log, addr, client)
    if not nt.init() then
        return
    end

    nt.createChannel "DbgMaster"

    if error_log then
        nt.createThread("error", package.path, package.cpath, ([[
            local err = thread.channel "errlog"
            local log = require "common.log"
            log.file = %q
            repeat
                local ok, msg = err:pop(0.05)
                if ok then
                    log.error("ERROR:" .. msg)
                end
            until MgrUpdate()
        ]]):format(error_log))
    end

    nt.createThread("master", package.path, package.cpath, ([[
        local parseAddress  = require "common.parseAddress"
        local serverFactory = require "common.serverFactory"
        local server = serverFactory(parseAddress(%q, %s))
]]):format(addr, client) .. [=[
        local dbg_io = {}
        function dbg_io:event_in(f)
            self.fsend = f
        end
        function dbg_io:event_close(f)
            self.fclose = f
        end
        function dbg_io:update()
            local data = server.recvRaw()
            if data ~= '' then
                self.fsend(data)
            end
            return true
        end
        function dbg_io:send(data)
            server.sendRaw(data)
        end
        function dbg_io:close()
            server.close()
            self.fclose()
        end

        local select = require "common.select"
        local master = require 'backend.master.mgr'
        master.init(dbg_io)
        repeat
            select.update(0.05)
            master.update()
        until MgrUpdate()
        select.closeall()
    ]=])
end
