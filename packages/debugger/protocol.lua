local json = require 'json'

local m = {}

local function recv(s, bytes)
    bytes = bytes or ''
    s.bytes = s.bytes and (s.bytes .. bytes) or bytes
    while true do
        if s.length then
            if s.length <= #s.bytes then
                local res = s.bytes:sub(1, s.length)
                s.bytes = s.bytes:sub(s.length + 1)
                s.length = nil
                return res
            end
            return
        end
        local pos = s.bytes:find('\r\n', 1, true)
        if not pos then
            return
        end
        if pos <= 15 or s.bytes:sub(1, 16) ~= 'Content-Length: ' then
            return error('Invalid protocol.')
        end
        local length = tonumber(s.bytes:sub(17, pos))
        if not length then
            return error('Invalid protocol.')
        end
        s.bytes = s.bytes:sub(pos + 4)
        s.length = length
    end
end

function m.recv(bytes, stat)
    local pkg = recv(stat, bytes)
    if pkg then
        --if print then print('[recv]', pkg) end
        local res, err = json.decode(pkg)
        if res then
            return res
        end
        error(('%s\n%s'):format(err, pkg))
    end
end

function m.send(cmd)
    --if cmd.type == 'response' and cmd.success == false then
    --    error(debug.traceback(cmd.message))
    --end
    local pkg = assert(json.encode(cmd))
    --if print then print('[send]', pkg) end
    return ('Content-Length: %d\r\n\r\n%s'):format(#pkg, pkg)
end

return m
