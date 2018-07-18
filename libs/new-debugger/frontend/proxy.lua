local client = require 'new-debugger.frontend.client'
local server_factory = require 'new-debugger.frontend.server'
local server
local seq = 0
local initReq
local m = {}

local function newSeq()
    seq = seq + 1
    return seq
end

function m.send(pkg)
    if server then
        server.send(pkg)
    elseif pkg.type == 'request' then
        if pkg.command == 'initialize' then
            client.send {
                type = 'response',
                seq = newSeq(),
                command = pkg.command,
                request_seq = pkg.seq,
                success = true,
                body = require 'new-debugger.capabilities',
            }
            pkg.__norepl = true
            initReq = pkg
            return
        elseif pkg.command == 'attach' then
            local ip = pkg.arguments.ip
            local port = pkg.arguments.port
            if ip == 'localhost' then
                ip = '127.0.0.1'
            end
            server = server_factory.tcp(m, ip, port)
            server.send(initReq)
            server.send(pkg)
        elseif pkg.command == 'launch' then
            -- TODO
        end
    end
end

function m.recv(pkg)
    client.send(pkg)
end

return m
