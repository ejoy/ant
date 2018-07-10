local srv = require 'new-debugger.master.server'
local request = require 'new-debugger.master.request'
local response = require 'new-debugger.master.response'
local mgr = require 'new-debugger.master.mgr'

local function runIdle()
    mgr.update()
    if mgr.isState 'terminated' then
        mgr.setState 'birth'
        return false
    end
    local req = srv.recv()
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

srv.start(4278)

local listen = true

return function()
    if listen then
        if not srv.select(200) then
            return
        end
        listen = false
    end

    while true do
        local quit = runIdle()
        if quit then
            break
        end
    end
end
