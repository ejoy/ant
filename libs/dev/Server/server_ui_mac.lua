local root = os.getenv "ANTGE" or "."

local function HandleResponse(resp_table)
    for _,v in ipairs(resp_table) do
        --this is just log
        --for now, just show on the multitext
        --need to unpack twice, because the text is packed too

        local log_table = v[2]
        print(v[1], log_table[1], log_table[2])

    end
end

function init()
    local server_framework = require "server_framework"
    server_framework:init("127.0.0.1", 8888)

    local mobiledevices = require "libimobiledevicelua"
    local devices = mobiledevices.GetDevices()
    for _, udid in ipairs(devices) do
        server_framework:HandleCommand(udid, "CONNECT")
    end

    server_framework:SetProjectDirectoryPath("/Users/ejoy/Desktop/Engine/ant/libs")

    server_framework:HandleCommand("all", "RUN", "ios_main.lua")
end

local count = 1

function mainloop()
    server_framework:update()
    HandleResponse(server_framework:RecvResponse())
end
