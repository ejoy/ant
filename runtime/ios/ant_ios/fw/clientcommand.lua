local MAX_CALC_CHUNK = 62*1024
local clientcommand = {}
--cmd while recieving data from server
--there are two types of file data
--one will store as file
--one will store in the memory
--the data stored in the memory will have record in mem_file_status
function clientcommand.FILE(resp, self)
    --resp[1] is cmd name "FILE"
    --resp[2] is the file path in client
    --resp[3] is the file hash value
    --resp[4] is the progress "current/total"
    --resp[5] is the file data
    assert(resp[1] == "FILE")
    local progress = resp[4]

    local slash = string.find(progress, "%/")
    local offset = tonumber(string.sub(progress, 1, slash - 1))
    local total_pack = tonumber(string.sub(progress, slash+1, -1))
    local file_path = resp[2]

    --store in file
    --file dose not exist on server
    local hash = resp[3]

    print("write file", file_path, hash)
    if not hash then
        --TODO: handle this situation
        print("error: server hash not founc")
        return
    end

    --print("package info", resp[1], resp[2],resp[4], resp[5])
    --if is the first package, will delete the origin file
    --if is other package, will add to the existing file
    --TODO: consider if the order is not correct
    if offset <= MAX_CALC_CHUNK then
        self.vfs:write(hash, resp[5])
    else
        self.vfs:write(hash, resp[5], "ab")
    end

    if offset >= total_pack then
        --TODO version management/control
        --the file is complete, inform out side
        print("get new file :  "..file_path)
        self.linda:send("new file", file_path)
    end

    print("write file", file_path, self.vfs)
end

--handle error
--for now just print the error message
function clientcommand.ERROR(resp, self)
    for k, v in pairs(resp) do
        print(k, v)
    end
    self.linda:send("mem_data", "ERROR")
end

function clientcommand.EXIST_CHECK(resp, self)
    assert(resp[1] == "EXIST_CHECK", "COMMAND: "..resp[1].." invalid, shoule be EXIST_CHECK")
    local result = resp[2]
    print("get exist check result: "..tostring(result))

    self.linda:send("file exist", result)
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