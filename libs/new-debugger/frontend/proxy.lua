local client = require 'new-debugger.frontend.client'
local server_factory = require 'new-debugger.frontend.server'
local parser = require 'new-debugger.parser'
local server
local seq = 0
local initReq
local m = {}

local function newSeq()
    seq = seq + 1
    return seq
end

local function response_initialize(req)
    client.send {
        type = 'response',
        seq = newSeq(),
        command = 'initialize',
        request_seq = req.seq,
        success = true,
        body = require 'new-debugger.capabilities',
    }
end

local function response_error(req, msg)
    client.send {
        type = 'response',
        seq = newSeq(),
        command = req.command,
        request_seq = req.seq,
        success = false,
        message = msg,
    }
end

function m.send(pkg)
    if server then
        if pkg.type == 'request' and pkg.command == 'setBreakpoints' then
            local source = pkg.arguments.source
            local f = loadfile(source.path)
            if f then
                source.si = {}
                parser(source.si, f)
            end
        end
        server.send(pkg)
    elseif not initReq then
        if pkg.type == 'request' and pkg.command == 'initialize' then
            response_initialize(pkg)
            pkg.__norepl = true
            initReq = pkg
        else
            response_error(pkg, 'not initialized')
        end
    else
        if pkg.type == 'request' then
            if pkg.command == 'attach' then
                local args = pkg.arguments
                if args.processId or args.processName then
                    response_error(pkg, 'not support')
                    return
                end
                local ip = args.ip
                local port = args.port
                if ip == 'localhost' then
                    ip = '127.0.0.1'
                end
                server = server_factory.tcp(m, ip, port)
                server.send(initReq)
                server.send(pkg)
            elseif pkg.command == 'launch' then
                -- TODO
                response_error(pkg, 'not support')
            else
                response_error(pkg, 'error request')
            end
        end
    end
end

function m.recv(pkg)
    client.send(pkg)
end

return m
