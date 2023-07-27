local ltask = require "ltask"
local socket = require "socket"

local SERVICE_ROOT <const> = 1
local function post_spawn(name, ...)
    return ltask.send(SERVICE_ROOT, "spawn", name, ...)
end

ltask.uniqueservice("arguments", ...)

local fd, err
while true do
    fd, err = socket.bind("tcp", "0.0.0.0", 2018)
    if fd then
        break
    end
    print(err)
    ltask.sleep(10)
end
post_spawn "ios.event"
post_spawn "android.event"
while true do
    local newfd = socket.listen(fd)
    post_spawn("agent", newfd)
end
