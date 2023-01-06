local thread = require "bee.thread"

local function createChannel(name)
    local ok, err = pcall(thread.newchannel, name)
    if not ok then
        if err:sub(1,17) ~= "Duplicate channel" then
            error(err)
        end
    end
    return not ok
end

local function hasChannel(name)
    local ok = pcall(thread.channel, name)
    return ok
end

local master_thread

local function createThread(script)
    return thread.thread(thread.bootstrap_lua .. script, thread.bootstrap_c)
end

ExitGuard = setmetatable({}, {__gc=function()
    if master_thread then
        local mt = master_thread
        master_thread = nil
        local c = thread.channel "DbgMaster"
        c:push(nil, "EXIT")
        thread.wait(mt)
    end
end})

local function hasMaster()
    return hasChannel "DbgMaster"
end

local function initMaster(logpath, address)
    if createChannel "DbgMaster" then
        return
    end

    master_thread = createThread(([[
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
    ]]):format(logpath, address))
end

return {
    init = initMaster,
    has = hasMaster,
}
