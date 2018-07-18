(function()
    local exepath = package.cpath:sub(1, (package.cpath:find(';') or 0)-6)
    package.path = exepath .. '..\\?.lua;'
    package.cpath = exepath .. '?.dll;'
end)()

--log = require 'new-debugger.log'
--log.file = 'dbg.log'

local select = require 'new-debugger.frontend.select'
local client = require 'new-debugger.frontend.client'

print = nil

client.initialize()

while true do
    client.update()
    select.update()
end
