local nt = require "backend.master.named_thread"

return function (logpath, address, errthread)
    if not nt.init() then
        return
    end

    nt.createChannel "DbgMaster"

    if errthread then
        nt.createThread("error", ([[
            local err = thread.channel "errlog"
            local log = require "common.log"
            log.file = %q..'/error.log'
            while true do
                local ok, msg = err:pop(0.05)
                if ok then
                    log.error("ERROR:" .. msg)
                end
                MgrUpdate()
            end
        ]]):format(logpath))
    end

    nt.createThread("master", ([[
        local dbg_io = require "common.io"(%s)
        local master = require "backend.master.mgr"
        local log = require "common.log"
        log.file = %q..'/master.log'
        master.init(dbg_io)
        while true do
            master.update()
            MgrUpdate()
        end
    ]]):format(address, logpath))
end
