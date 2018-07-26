
local lsocket = require 'lsocket'
local cdebug = require 'debugger.frontend'
local proto = require 'new-debugger.protocol'
local select = require 'new-debugger.frontend.select'

local function tcpsend(fd, s)
    local from = 1
    local len = #s
    while from <= len do
        if lsocket.select(nil, {fd}) then
            from = from + assert(fd:send(s:sub(from)))
        end
    end
end

local function tcpchannel(proxy, fd)
    local stat = {}
    select.read(fd, function()
        while true do
            local pkg = proto.recv(fd:recv() or '', stat)
            if pkg then
                proxy.recv(pkg)
            else
                break
            end
        end
    end)
    local m = {}
    function m.send(pkg)
        tcpsend(fd, proto.send(pkg))
    end
    return m
end

local function tcp_client(proxy, ip, port)
    local fd = assert(lsocket.connect(ip, port))
    return tcpchannel(proxy, fd)
end

local function tcp_server(proxy, ip)
    local port = 11000
    local socket
    repeat
        port = port + 1
        socket = assert(lsocket.bind(ip, port))
    until socket
    
    local listen = {}
    function listen:accept(timeout)
        if not lsocket.select({socket}, timeout) then
            return
        end
        local fd = socket:accept()
        return tcpchannel(proxy, fd)
    end
    return listen, port
end

return {
    tcp_client = tcp_client,
    tcp_server = tcp_server,
}
