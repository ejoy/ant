local request = require 'new-debugger.backend.master.request'
local response = require 'new-debugger.backend.master.response'
local mgr = require 'new-debugger.backend.master.mgr'
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

function m.init(type, ...)
    io = require('new-debugger.backend.master.io.' .. type)
    io.start(...)
    mgr.add_io(io)
end

function m.update()
    if not io.update(0.05) then
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
