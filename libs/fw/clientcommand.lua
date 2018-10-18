local MAX_CALC_CHUNK = 62*1024
local clientcommand = {}

--handle error
--for now just print the error message
function clientcommand.ERROR(resp, self)
    for k, v in pairs(resp) do
        print(k, v)
    end
    self.linda:send("mem_data", "ERROR")
end

function clientcommand.DIR(resp, self)

    print(resp[1], resp[2], resp[3], resp[4])

end

function clientcommand.RUN(resp, self)
    print("run cmd", resp[1], resp[2])
    self.run_cmd_cache = resp[2]

    print("request root")
    --self.io:Send(self.current_connect, {"REQUEST_ROOT"})
    self.linda:send("io_send", {"REQUEST_ROOT"})
    --_linda:send("run", resp[2])
end

function clientcommand.SCREENSHOT(resp, self)
    print("get screenshot command")

    --resp[1] is "SCREENSHOT"
    --resp[2] screenshot id
    --todo maybe more later

    self.linda:send("screenshot_req", resp)
end

return clientcommand