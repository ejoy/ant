
local lsocket = require 'lsocket'
local cdebug = require 'debugger.frontend'
local proto = require 'new-debugger.protocol'
local select = require 'new-debugger.frontend.select'

local function tcpsend(fd, s)
    local from = 1
    local len = #s
    while from <= len do
        lsocket.select(nil, {fd})
        from = from + assert(fd:send(s:sub(from)))
    end
end

local function tcp(proxy, ip, port)
    local fd = assert(lsocket.connect(ip, port))
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

return {
    tcp = tcp,
}
