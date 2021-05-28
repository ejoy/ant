local ltask = require "ltask"
local manager = require "ltask.manager"
local socket = require "socket"

local SERVICE_ROOT <const> = 1
local function post_spawn(name, ...)
    return ltask.send(SERVICE_ROOT, "spawn", name, ...)
end

manager.spawn("arguments", ...)
manager.spawn "vfs"
manager.spawn "log.manager"
manager.spawn "debug.listen"
post_spawn "ios.event"

local fd = socket.bind("tcp", "127.0.0.1", 2018)
while true do
    local newfd = socket.listen(fd)
    post_spawn("agent", newfd)
end
