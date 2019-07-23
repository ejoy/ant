local nt = require "backend.master.named_thread"

return function (error_log, address)
    if not nt.init() then
        return
    end

    nt.createChannel "DbgMaster"

    if error_log then
        nt.createThread("error", package.path, package.cpath, ([[
            local err = thread.channel "errlog"
            local log = require "common.log"
            log.file = %q
            while true do
                local ok, msg = err:pop(0.05)
                if ok then
                    log.error("ERROR:" .. msg)
                end
                MgrUpdate()
            end
        ]]):format(error_log))
    end

    nt.createThread("master", package.path, package.cpath, ([[
        local dbg_io = require "common.io"(%s)
        local master = require "backend.master.mgr"
        master.init(dbg_io)
        while true do
            master.update()
            MgrUpdate()
        end
    ]]):format(address))
end
