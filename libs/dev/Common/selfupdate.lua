-- used for self update
-- keep it as simple as we can
local filemanager = require "filemanager"
local file_mgr = filemanager.new()

local lanes = require "lanes"
if lanes.configure then
    lanes.configure({with_timers = false, on_state_create = custom_on_state_create})
end
local linda = lanes.linda()

local function CreateIOThread(linda, home_dir)
    local client = require "client"
    local c = client.new("127.0.0.1", 8888, linda, home_dir)
print("io thread created")
    while true do
        c:mainloop(0.001)
        --print("io mainloop updating")
        local resp = c:pop()
        if resp then
            c:process_response(resp)
        end
    end
end

function SelfUpdate(bundle_dir)
    --table of paths to check
    file_mgr:ReadDirStructure(bundle_dir .. "/Documents/dir.txt")
    file_mgr:ReadFilePathData(bundle_dir .. "/Documents/file.txt")

    local client_io = lanes.gen("*", CreateIOThread)(linda, bundle_dir)

    local check_path = {}

    check_path.appmain = "/dev/Client/appmain.lua"
    check_path.client = "/dev/Client/client.lua"
    check_path.filemanager = "/dev/Common/filemanager.lua"
    check_path.fileprocess = "/dev/Common/fileprocess.lua"
    check_path.lanes = "/dev/Common/lanes.lua"
    check_path.pack = "/dev/Common/pack.lua"

    local real_path_table = {}
    for k, v in pairs(check_path) do
        local path = v
        local request = {"EXIST", path }
        print("request file: "..path)

        linda:send("request", request)

        --wait here
        ---[[
        while true do
            local _, value = linda:receive(0.001, "file exist")
            if value ~= nil then
                if value == "exist" then
                    print(path .. " exist")

                    real_path_table[k] = file_mgr:GetRealPath(path)

                    break
                elseif value == "not exist" then
                    print(path .. " not exist!! " .. tostring(value))
                    assert(false)
                elseif value == "diff hash" then
                    --hash is different, request the one on server
                    --return true if succeed
                    print("new request " .. path)
                    local file_request = {"GET", path}
                    linda:send("request", file_request)

                    --TODO file not exist
                    --wait here
                    while true do
                        local _, value = linda:receive(0.001, "new file")
                        if value then
                            print("received msg", path)
                            --put into the id_table and file_table
                            file_mgr:AddFileRecord(value[1], value[2])
                            print("add file recode: "..value[1] .. " and "..value[2])
                            file_mgr:WriteDirStructure(bundle_dir.."/Documents/dir.txt")
                            file_mgr:WriteFilePathData(bundle_dir.."/Documents/file.txt")

                            print("file name", path)
                            local real_path = file_mgr:GetRealPath(value[2])
                            --real_path = bundle_dir .. "/Documents/" .. real_path

                            real_path_table[k] = real_path
                            --add to file exist cache
                            print("add to exist cache: "..path)
                            break
                        end
                    end
                end

                break
            end
        end
    end

    file_mgr:WriteDirStructure(bundle_dir .. "/Documents/dir.txt")
    file_mgr:WriteFilePathData(bundle_dir .. "/Documents/file.txt")

    print("=======hello=======")

    for k, v in pairs(real_path_table) do
        print(k, v)
    end

    return real_path_table
end
