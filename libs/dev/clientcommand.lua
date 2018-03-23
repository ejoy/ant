--一些基本的文件接口,用于服务器和客户端文件操作
package.cpath = "../../clibs/?.dll"

local clientcommand = {}

--cmd while recieving data from server
function clientcommand.FILE(resp)
    --resp[1] is cmd name "FILE"
    --resp[2] is the file path in client
    --resp[3] is the file hash value
    --resp[4] is the progress "current/total"
    --resp[5] is the file data

    assert(resp[1] == "FILE")
    local file_path = resp[2]
    local hash = resp[3]
    --file dose not exist on server
    if not hash then
        --TODO: handle this situation
        return
    end

    --use temp name
    local file_path_hash = file_path.."-"..tostring(hash)
    local progress = resp[4]

    print("recieved", resp[1],resp[2],resp[4])
    local slash = string.find(progress, "%/")
    local offset = tonumber(string.sub(progress, 1, slash - 1))
    --print("package info", resp[1], resp[2],resp[4], resp[5])
    --if is the first package, will delete the origin file
    --if is other package, will add to the existing file
    --TODO: consider if the order is not correct
    local file  = nil
    if offset == 1 then
        --we should use a temp file, for now is file_path+hash value
        file = io.open(file_path_hash, "wb")
    else
        file = io.open(file_path_hash, "ab")
    end

    if file == nil then
        return
    end

    --output to client file directory
    io.output(file)
    io.write(resp[5])   --write the data into the client file
    io.close(file)

    local total_pack = tonumber(string.sub(progress, slash+1, -1))
    if offset >= total_pack then
        --the final package, the file is complete, change the name to normal name
        --for now, just remove the old file
        --TODO version management/control
        os.remove(file_path)
        os.rename(file_path_hash, file_path)
    end
end

--handle error
--for now just print the error message
function clientcommand.ERROR(resp)
    for k, v in pairs(resp) do
        print(k, v)
    end
end

function clientcommand.EXIST_CHECK(resp)
    for k, v in pairs(resp) do
        print(k, v)
    end
end

function clientcommand.DIR(resp)

    print(resp[1], resp[2], resp[3], resp[4])

end
return clientcommand
