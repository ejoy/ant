(function()
    local exepath = package.cpath:sub(1, (package.cpath:find(';') or 0)-6)
    package.path = arg[1]:gsub('!', exepath)
    package.cpath = arg[2]:gsub('!', exepath)
end)()

--log = require 'debugger.log'
--log.file = 'dbg.log'

local select = require 'debugger.frontend.select'
local client = require 'debugger.frontend.client'

print = nil

client.initialize()

while true do
    client.update()
    select.update()
end
