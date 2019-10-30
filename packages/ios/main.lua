local platform = require "platform"

if platform.OS ~= "iOS" then
    return {
        error = "Not running in iOS"
    }
end

local fs = require "filesystem"
local machine = platform.machine()
local name, major, minor = machine:match "(%a+)(%d+),(%d+)"
local path = fs.path(("/pkg/ant.ios/%s.lua"):format(name))
if not fs.exists(path) then
    return {
        error = ("unknown matchine `%s`"):format(machine)
    }
end

-- see the https://en.wikipedia.org/wiki/List_of_iOS_devices
major = tonumber(major)
minor = tonumber(minor)
local res = assert(fs.loadfile(path))(major, minor)
if not res then
    return {
        error = ("unknown matchine `%s`"):format(machine)
    }
end

return res
