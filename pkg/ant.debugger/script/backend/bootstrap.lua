local thread = require "bee.thread"

local m = {}

local function hasMaster()
    local ok = pcall(thread.channel, "DbgMaster")
    return ok
end

local function initMaster(logpath, address)
    if hasMaster() then
        return
    end
    thread.newchannel "DbgMaster"
    local mt = thread.thread(([[
        package.path = %q
        local log = require "common.log"
        log.file = %q..'/master.log'
        local ok, err = xpcall(function()
            local network = require "common.network"(%q)
            local master = require "backend.master.mgr"
            master.init(network)
            master.update()
        end, debug.traceback)
        if not ok then
            log.error("ERROR:" .. err)
        end
    ]]):format(
        package.path,
        logpath,
        address
    ))
    ExitGuard = setmetatable({}, {__gc=function()
        local c = thread.channel "DbgMaster"
        c:push(nil, "EXIT")
        thread.wait(mt)
    end})
end

local function startWorker(logpath)
    local log = require 'common.log'
    log.file = logpath..'/worker.log'
    require 'backend.worker'
end

function m.start(logpath, address)
    initMaster(logpath, address)
    startWorker(logpath)
end

function m.attach(logpath)
    if hasMaster() then
        startWorker(logpath)
    end
end

return m
