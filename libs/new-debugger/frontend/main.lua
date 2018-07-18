(function()
    local exepath = package.cpath:sub(1, (package.cpath:find(';') or 0)-6)
    package.path = exepath .. '..\\?.lua;'
    package.cpath = exepath .. '?.dll;'
end)()

local lsocket = require 'lsocket'
local cdebug = require 'debugger.frontend'
local stdin = require 'new-debugger.frontend.stdin'
local select = require 'new-debugger.frontend.select'
local proto = require 'new-debugger.protocol'

local client_fd = assert(lsocket.connect('127.0.0.1', 4278))

local function sendstring(fd, s)
    local from = 1
    local len = #s
    while from <= len do
        lsocket.select(nil, {fd})
        from = from + assert(fd:send(s:sub(from)))
    end
end

local function stdin_read()
    local s = stdin.fd:recv()
    if s then
        sendstring(client_fd, s)
    end
end

local function client_read()
    local s = client_fd:recv()
    if s then
        io.stdout:write(s)
    end
end

select.read(stdin.fd, stdin_read)
select.read(client_fd, client_read)

io.stdin:setvbuf 'no'
io.stdout:setvbuf 'no'
cdebug.filemode(io.stdin, 'b')
cdebug.filemode(io.stdout, 'b')

while true do
    stdin.update()
    select.update(0.05)
end
