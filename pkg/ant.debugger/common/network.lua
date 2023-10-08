local select = require 'common.select'
local proto = require 'common.protocol'

local function parseAddress(address, client)
    if address:sub(1,1) == '@' then
        return {
            protocol = 'unix',
            address = address:sub(2),
            client = client,
        }
    end
    local ipv4, port = address:match("(%d+%.%d+%.%d+%.%d+):(%d+)")
    if ipv4 then
        return {
            protocol = 'tcp',
            address = ipv4,
            port = tonumber(port),
            client = client,
        }
    end
    local ipv6, port = address:match("%[([%d:a-fA-F]+)%]:(%d+)")
    if ipv6 then
        return {
            protocol = 'tcp6',
            address = ipv6,
            port = tonumber(port),
            client = client,
        }
    end
    error "Invalid address."
end

local function open(address, client)
    local t = parseAddress(address, client)
    local m = {}
    local session
    local srvfd
    local write = ''
    local e_send = function(_) end
    local e_close = function() end
    local stat = {}
    function t.event(status, fd)
        if status == 'connect start' then
            assert(t.client)
            srvfd = fd
            return
        end
        if status == 'connect failed' then
            assert(t.client)
            select.close(srvfd)
            select.wantconnect(t)
            return
        end
        if status == 'close' then
            if session == fd then
                if t.client then
                    srvfd = nil
                    select.wantconnect(t)
                end
                e_close()
                session = nil
            end
            return
        end
        if session then
            fd:close()
            return
        end
        session = fd
        select.send(session, write)
        write = ''
    end
    if t.client then
        select.wantconnect(t)
    else
        srvfd = assert(select.listen(t))
    end
    function m.event_in(f)
        e_send = f
    end
    function m.event_close(f)
        e_close = function()
            write = ''
            stat = {debug=stat.debug}
            f()
        end
    end
    function m.update()
        select.update(0)
        local data = m.recv()
        if data ~= '' then
            e_send(data)
        end
        return true
    end
    function m.send(data)
        if not session then
            write = write .. data
            return
        end
        select.send(session, data)
    end
    function m.recv()
        if not session then
            return ''
        end
        return select.recv(session)
    end
    function m.close()
        select.close(session)
        write = ''
    end
    function m.debug(v)
        stat.debug = v
    end
    function m.sendmsg(pkg)
        m.send(proto.send(pkg, stat))
    end
    function m.recvmsg()
        return proto.recv(m.recv(), stat)
    end
    function m.closeall()
        select.closeall()
    end
    return m
end

return open
