local proto = require 'debugger.protocol'

local m = {}

function m:event_in(f)
    m.host_send = function (pkg)
        f(proto.send(pkg))
    end
end

function m:event_close()
end

function m:update()
    return true
end

function m:send(data)
    m.host_recv(proto.recv(data, {}))
end

function m:close()
end

return m
