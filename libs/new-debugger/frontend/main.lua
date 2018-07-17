local lsocket = require 'lsocket'
local cdebug = require 'debugger.frontend'
local stdin = require 'new-debugger.frontend.stdin'
local select = require 'new-debugger.frontend.select'
local proto = require 'new-debugger.protocol'

local client_fd = assert(lsocket.connect('127.0.0.1', 4278))

local function sendstring(fd, s)
    test.messagebox(s, tostring(fd))
    local from = 1
    local len = #s
    while from <= len do
        lsocket.select(nil, {fd})
        from = from + assert(fd:send(s:sub(from)))
    end
end

local function stdin_read()
    sendstring(client_fd, stdin.fd:recv())
end

local function client_read()
    io.output:write(client_fd:recv())
end

select.read(stdin.fd, stdin_read)
select.read(client_fd, client_read)

while true do
    stdin.update()
    select.update(0.05)
end

print('ok')
