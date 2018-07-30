local request = require 'debugger.backend.master.request'
local response = require 'debugger.backend.master.response'
local mgr = require 'debugger.backend.master.mgr'
local cdebug = require 'debugger.backend'

local io
local m = {}

local function runIdle()
    mgr.update()
    if mgr.isState 'terminated' then
        mgr.setState 'birth'
        return false
    end
    local req = io.recv()
    if not req then
        return true
    end
    if req.type == 'request' then
        if mgr.isState 'birth' then
            if req.command == 'initialize' then
                request.initialize(req)
            else
                response.error(req, ("`%s` not yet implemented.(birth)"):format(req.command))
            end
        else
            local f = request[req.command]
            if f then
                if f(req) then
                    return true
                end
            else
                response.error(req, ("`%s` not yet implemented.(idle)"):format(req.command))
            end
        end
    end
    return false
end

function m.init()
    local master = cdebug.start 'master'
    if not master then
        return false
    end
    local type = os.getenv('_DBG_IOTYPE') or 'tcp_server'
    io = require('debugger.backend.master.io.' .. type)
    io.start('127.0.0.1', os.getenv('_DBG_IOPORT') and tonumber(os.getenv('_DBG_IOPORT')) or 4278)
    mgr.init(io, master)
    return true
end

function m.update()
    if not io.update() then
        return
    end

    while true do
        local quit = runIdle()
        if quit then
            break
        end
    end
end

return m
