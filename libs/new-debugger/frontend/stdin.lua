local lsocket = require 'lsocket'
local cdebug = require 'debugger.frontend'

local function sendstring(fd, s)
    local from = 1
    local len = #s
    while from <= len do
        lsocket.select(nil, {fd})
        from = from + assert(fd:send(s:sub(from)))
    end
end

local function init_async_stdin()
    if cdebug.os() == 'windows' then
        local port = 12000
        local socket
        repeat
            port = port + 1
            socket = assert(lsocket.bind('127.0.0.1', port))
        until socket
        local ofd = assert(lsocket.connect('127.0.0.1', port))
        lsocket.select {socket}
        local ifd = socket:accept()
        socket:close()
        lsocket.select({}, {ofd})
        local astdin = cdebug.async_stdin()
        return {
            fd = ifd,
            update = function()
                if not ofd then
                    return
                end
                local ok, s = astdin.read()
                if not ok then
                    ofd:close()
                    ofd = nil
                    return
                end
                if s then
                    sendstring(ofd, s)
                    return
                end
            end,
        }
    else
        --TODO
    end
end

return init_async_stdin()
