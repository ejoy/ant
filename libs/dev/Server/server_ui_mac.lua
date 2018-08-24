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

local function server_test_func(value)
    print("dbg_test_server " .. tostring(value[1]) .. " and ".. tostring(value[2]))
    server_framework:SendPackage({"DBG_SERVER_SENT", "54321"})
end

server_framework:RegisterIOCommand("DBG_CLIENT_SENT", server_test_func)

function init()

    print("Platform", PLATFORM)

    local mobiledevices = require "libimobiledevicelua"
    local devices = mobiledevices.GetDevices()
    for _, udid in ipairs(devices) do
        server_framework:HandleCommand(udid, "CONNECT")
    end

    server_framework:SetProjectDirectoryPath("/Users/ejoy/Desktop/Engine/ant")
    server_framework:HandleCommand("all", "RUN", "/libs/testlua.lua")
end



local count = 1
function mainloop()
    --ework:HandleCommand("all", "RUN", "testlua.lua")
    --print("a")
    ---[[
    server_framework:update()
    --HandleResponse(server_framework:RecvResponse())

    --print("count", count)
    --]]
end
