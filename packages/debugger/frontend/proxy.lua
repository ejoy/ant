local server_factory = require 'debugger.frontend.server'
local proto = require 'debugger.protocol'
local socket = require 'debugger.socket'
local fs = require 'debugger.filesystem'
local server
local client = {}
local seq = 0
local initReq
local m = {}
local io

function client.send(pkg)
    io:send(proto.send(pkg))
end

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
        body = require 'debugger.capabilities',
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

local function request_runinterminal(args)
    client.send {
        type = 'request',
        --seq = newSeq(),
        command = 'runInTerminal',
        arguments = args
    }
end

local function create_terminal(args, port)
    local command = {}
    if args.runtimeExecutable then
        command[#command + 1] = args.runtimeExecutable
        command[#command + 1] = args.runtimeArgs
    elseif args.luaexe then
        command[#command + 1] = args.luaexe

        if args.path then
            command[#command + 1] = '-e'
            command[#command + 1] = ("package.path=[[%s]];"):format(args.path)
        end
        if args.cpath then
            command[#command + 1] = '-e'
            command[#command + 1] = ("package.cpath=[[%s]];"):format(args.cpath)
        end
        if type(args.arg0) == 'string' then
            command[#command + 1] = args.arg0
        elseif type(args.arg0) == 'table' then
            for _, v in ipairs(args.arg0) do
                command[#command + 1] = v
            end
        end
        command[#command + 1] = args.program
        if type(args.arg) == 'string' then
            command[#command + 1] = args.arg
        elseif type(args.arg) == 'table' then
            for _, v in ipairs(args.arg) do
                command[#command + 1] = v
            end
        end
    else
        return false
    end
    if not args.env then
        args.env = {}
    end
    args.env._DBG_IOTYPE = 'tcp_client'
    args.env._DBG_IOPORT = tostring(port)
    request_runinterminal {
        kind = args.console == 'integratedTerminal' and 'integrated' or 'external',
        title = 'Lua Debug',
        cwd = args.cwd or fs.remove_filename(command[1]),
        env = args.env,
        args = command,
    }
    return true
end

function m.send(pkg)
    if server then
        if pkg.type == 'response' and pkg.command == 'runInTerminal' then
            return
        end
        server.send(pkg)
    elseif not initReq then
        if pkg.type == 'request' and pkg.command == 'initialize' then
            pkg.__norepl = true
            initReq = pkg
            response_initialize(pkg)
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
                server = server_factory.tcp_client(m, ip, port)
                server.send(initReq)
                server.send(pkg)
            elseif pkg.command == 'launch' then
                local args = pkg.arguments
                if args.console == 'integratedTerminal' or args.console == 'externalTerminal' then
                    local listen, port = server_factory.tcp_server(m, '127.0.0.1')
                    if not create_terminal(args, port) then
                        response_error(pkg, 'launch failed')
                        return
                    end
                    server = listen:accept(60)
                    if not server then
                        response_error(pkg, 'launch failed')
                        return
                    end
                    server.send(initReq)
                    server.send(pkg)
                    return
                end
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

function m.update()
    socket.update()
    io:update()
end

function m.initialize(io_)
    io = io_
    local stat = {}
    io:event_in(function(data)
        while true do
            local pkg = proto.recv(data, stat)
            if pkg then
                data = ''
                m.send(pkg)
            else
                break
            end
        end
    end)
end

return m
