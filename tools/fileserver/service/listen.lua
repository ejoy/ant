local ltask = require "ltask"
local socket = require "socket"

local SERVICE_ROOT <const> = 1
local function post_spawn(name, ...)
    return ltask.send(SERVICE_ROOT, "spawn", name, ...)
end

ltask.uniqueservice("arguments", ...)
post_spawn "ios.event"

local fd = socket.bind("tcp", "0.0.0.0", 2018)
while true do
    local newfd = socket.listen(fd)
    post_spawn("agent", newfd)
end
