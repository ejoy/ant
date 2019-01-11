local proxy = require 'debugger.frontend.proxy'
local io = require 'debugger.host.io'
local event = require 'debugger.host.event'
local response = require 'debugger.host.response'
local request = require 'debugger.host.request'
local status = require 'debugger.host.status'
local ev = require 'debugger.event'

proxy.initialize(io)

local tasks = {}

function request.task(f)
    return coroutine.resume(coroutine.create(f))
end

function request.wait(seq)
    local co, m = coroutine.running()
    if m then
        error 'Must be run in the coroutine'
    end
    tasks[seq] = co
    return coroutine.yield()
end

function request.send(pkg)
    io.host_send(pkg)
    return pkg.seq
end

function io.host_recv(pkg)
    if pkg.type == 'event' then
        if event[pkg.event] then
            event[pkg.event](pkg.body)
        end
    elseif pkg.type == 'response' then
        local co = tasks[pkg.request_seq]
        if co then
            tasks[pkg.request_seq] = nil
            if pkg.success then
                coroutine.resume(co, true, pkg.body)
            else
                coroutine.resume(co, false, pkg.message)
            end
        else
            if pkg.success then
                if response[pkg.command] then
                    response[pkg.command](pkg.body)
                end
            end
        end
    end
end

ev.on('gui-toolbar', function(vk)
    request.task(function()
        if status.status == 'stopped' then
            if vk == 'continue' then
                status.status = 'running'
                request.continue(status.threadId)
            elseif vk == 'stepover' then
                status.status = 'running'
                request.next(status.threadId)
            elseif vk == 'stepin' then
                status.status = 'running'
                request.stepIn(status.threadId)
            elseif vk == 'stop' then
                -- TODO
                --status.status = 'running'
                --request.terminate()
            elseif vk == 'stepout' then
                status.status = 'running'
                request.stepOut(status.threadId)
            end
        elseif status.status == 'running' then
            if vk == 'pause' then
                -- TODO
                if #status.threads > 0 then
                    request.pause(status.threads[1].id)
                end
            end
        end
    end)
end)

ev.on('gui-breakpoint', function(source, breakpoints)
    local bps = {}
    for k in pairs(breakpoints) do
        bps[#bps+1] = { line = k }
    end
    request.setBreakpoints({path=source}, bps)
end)

local m = {}

function m.initialize()
    request.initialize()
end

function m.update()
    proxy.update()
end

return m
