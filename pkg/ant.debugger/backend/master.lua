local thread = require "bee.thread"

local function hasMaster()
    local ok = pcall(thread.channel, "DbgMaster")
    return ok
end

local function initMaster(logpath, address)
    if hasMaster() then
        return
    end
    thread.newchannel "DbgMaster"
    local mt = thread.thread(thread.bootstrap_lua .. ([[
        local log = require "common.log"
        log.file = %q..'/master.log'
        local ok, err = xpcall(function()
            local network = require "common.network"(%s)
            local master = require "backend.master.mgr"
            master.init(network)
            master.update()
        end, debug.traceback)
        if not ok then
            log.error("ERROR:" .. err)
        end
    ]]):format(logpath, address), thread.bootstrap_c)
    ExitGuard = setmetatable({}, {__gc=function()
        local c = thread.channel "DbgMaster"
        c:push(nil, "EXIT")
        thread.wait(mt)
    end})
end

return {
    init = initMaster,
    has = hasMaster,
}
