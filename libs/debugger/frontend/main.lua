(function()
    local exepath = package.cpath:sub(1, (package.cpath:find(';') or 0)-6)
    package.path = arg[1]:gsub('!', exepath)
    package.cpath = arg[2]:gsub('!', exepath)
end)()

--log = require 'debugger.log'
--log.file = 'dbg.log'
print = nil

local socket = require 'debugger.socket'
local client = require 'debugger.frontend.client'

client.initialize()

while true do
    client.update()
    socket.update()
end
