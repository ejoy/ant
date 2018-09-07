(function()
    local exepath = package.cpath:sub(1, (package.cpath:find(';') or 0)-6)
    package.path = arg[1]:gsub('!', exepath)
    package.cpath = arg[2]:gsub('!', exepath)
end)()

--log = require 'debugger.log'
--log.file = 'dbg.log'
print = nil

local proxy = require 'debugger.frontend.proxy'
local io = require 'debugger.io.stdio' ()

proxy.initialize(io)

while true do
    proxy.update()
end
