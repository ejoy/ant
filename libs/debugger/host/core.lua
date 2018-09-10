local proxy = require 'debugger.frontend.proxy'
local io = require 'debugger.host.io'
local event = require 'debugger.host.event'
local response = require 'debugger.host.response'
local request = require 'debugger.host.request'
local status = require 'debugger.host.status'
local ev = require 'debugger.event'

proxy.initialize(io)

function request.send(pkg)
    io.host_send(pkg)
end

function io.host_recv(pkg)
    if pkg.type == 'event' then
        if event[pkg.event] then
            event[pkg.event](pkg.body)
        end
    elseif pkg.type == 'response' then
        if not pkg.success then
            return
        end
        if response[pkg.command] then
            response[pkg.command](pkg.body)
        end
    end
end

ev.on('gui-keyboard', function(vk)
    if vk == 'F5' then
        request.continue(status.threadId)
    elseif vk == 'F6' then
        --TODO threadId
        request.pause(status.threadId)
    elseif vk == 'F10' then
        request.next(status.threadId)
    elseif vk == 'F11' then
        request.stepIn(status.threadId)
    elseif vk == 'Shift+F11' then
        request.stepOut(status.threadId)
    end
end)

local m = {}

function m.initialize()
    request.initialize()
    request.attach()
    if status.capabilities.supportsConfigurationDoneRequest then
        request.configurationDone()
    end
    request.threads()
end

function m.update()
    proxy.update()
end

return m
