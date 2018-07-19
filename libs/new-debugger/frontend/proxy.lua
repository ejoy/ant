local client = require 'new-debugger.frontend.client'
local server_factory = require 'new-debugger.frontend.server'
local parser = require 'new-debugger.parser'
local fs = require 'cppfs'
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

local function request_runinterminal(args)
    client.send {
        type = 'request',
        --seq = newSeq(),
        command = 'runInTerminal',
        arguments = args
    }
end

local function create_terminal(args, port)
    if not args.luaexe then
        return
    end
    -- TODO
    local utf8 = "utf8" == args.sourceCoding
    local luaexe = fs.path(args.luaexe)
    local command = {}
    command[#command + 1] = luaexe:string()
    if args.path then
        command[#command + 1] = '-e'
        command[#command + 1] = ("package.path=[[%s]];"):format(args.path)
    end
    if args.cpath then
        command[#command + 1] = '-e'
        command[#command + 1] = ("package.cpath=[[%s]];"):format(args.cpath)
    end
    command[#command + 1] = '-e'
    command[#command + 1] = ("_DBG_IOTYPE='tcp_client';_DBG_IOPORT=%d"):format(port)
    if type(arg0) == 'string' then
        command[#command + 1] = arg0
    elseif type(arg0) == 'table' then
        for _, v in ipairs(arg0) do
            command[#command + 1] = v
        end
    end
    command[#command + 1] = args.program
    if type(arg) == 'string' then
        command[#command + 1] = arg
    elseif type(arg) == 'table' then
        for _, v in ipairs(arg) do
            command[#command + 1] = v
        end
    end
    request_runinterminal {
        kind = args.console == 'integratedTerminal' and 'integrated' or 'external',
        title = 'Lua Debug',
        cwd = args.cwd or luaexe:remove_filename():string(),
        env = args.env,
        args = command,
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
        if pkg.type == 'response' and pkg.command == 'runInTerminal' then
            return
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
                server = server_factory.tcp_client(m, ip, port)
                server.send(initReq)
                server.send(pkg)
            elseif pkg.command == 'launch' then
                local args = pkg.arguments
                if args.runtimeExecutable then
                    response_error(pkg, 'not support')
                    return
                end
                if args.console == 'integratedTerminal' or args.console == 'externalTerminal' then
                    local listen, port = server_factory.tcp_server(m, '127.0.0.1')
                    create_terminal(args, port)
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

return m
