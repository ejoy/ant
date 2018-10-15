--log = require 'debugger.log'
--log.file = 'dbg.log'
print = nil

local proxy = require 'debugger.frontend.proxy'
local io = require 'debugger.io.stdio' ()

proxy.initialize(io)

while true do
    proxy.update()
end
