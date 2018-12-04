package.cpath = package.cpath .. ";./clibs/mobiledevice/?.dll"

local ios = require 'mobiledevice'
local thread = require 'thread'

for _, udid in ipairs(ios.list()) do
    print('init', udid)
end

while true do
    local type, udid = ios.select()
    if type then
        print(type, udid)
    else
        thread.sleep(0.1)
    end
end
