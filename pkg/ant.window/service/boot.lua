local ltask = require "ltask"
local SERVICE_ROOT <const> = 1
local ServiceWindow

local request = ltask.request()
request:add { SERVICE_ROOT, "uniqueservice", "ant.window|world", ...}
request:add { SERVICE_ROOT, "uniqueservice", "ant.rmlui|rmlui"}
for req, resp in request:select() do
    if not resp then
        error(string.format("service %s init error: %s", req[3], req.error))
        return
    end
    if req[3] == "ant.window|world" then
        ServiceWindow = ltask.queryservice "ant.window|window"
        ltask.call(ServiceWindow, "create_window")
    end
end

ltask.call(ServiceWindow, "wait")
