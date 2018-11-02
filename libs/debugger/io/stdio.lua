local subprocess = require 'subprocess'
local STDIN = io.stdin
local STDOUT = io.stdout
local peek = subprocess.peek
subprocess.filemode(STDIN, 'b')
subprocess.filemode(STDOUT, 'b')
STDIN:setvbuf 'no'
STDOUT:setvbuf 'no'

local mt = {}
mt.__index = mt

function mt:event_in(f)
    self.f = f
end

function mt:event_close()
end

function mt:update()
    local n = peek(STDIN)
    if n > 0 then
        self.f(STDIN:read(n))
    end
    return true
end

function mt:send(data)
    STDOUT:write(data)
end

function mt:close()
end

return function()
    return setmetatable({}, mt)
end
