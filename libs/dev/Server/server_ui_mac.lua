package.loaded["winfile"].exist = function(path)
    if package.loaded["winfile"].attributes(path) then
        return true
    else
        return false
    end
end

local server_framework = require "server_framework"
--print(pcall(server_framework.init, server_framework, "127.0.0.1", 8888))
server_framework:init("127.0.0.1", 8888)

function init()

    print("Platform", PLATFORM)

    local mobiledevices = require "libimobiledevicelua"
    local devices = mobiledevices.GetDevices()
    for _, udid in ipairs(devices) do
        server_framework:HandleCommand(udid, "CONNECT")
    end

    server_framework:SetProjectDirectoryPath("/Users/ejoy/Desktop/Engine/ant/libs")
end

local count = 1
function mainloop()
    --ework:HandleCommand("all", "RUN", "testlua.lua")
    --print("a")
    ---[[
    --server_framework:update()
    --HandleResponse(server_framework:RecvResponse())

    count = count + 1
    if count == 1000 then
        server_framework:HandleCommand("all", "RUN", "testlua.lua")
    end
    --print("count", count)
    --]]
end
