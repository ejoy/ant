---used for initialize structure
log, cfuncs, pkg_dir, sb_dir = ...
f_table = cfuncs()

f_table.preloadc()
package.path = package.path .. ";" .. pkg_dir .. "/fw/?.lua;".. pkg_dir .. "/?.lua;"

require"fw_io"
require"fw_msgprocess"
local check_path = {}
--todo: self update it self, then self update again?
--put these file to local repo
table.insert(check_path, "/fw/fw_init.lua")
table.insert(check_path, "/fw/fw_io.lua")

table.insert(check_path, "/fw/fw_msgprocess.lua")
table.insert(check_path, "/fw/msg_process.lua")
table.insert(check_path, "/fw/clientcommand.lua")

table.insert(check_path, "/fw/fw_run.lua")
table.insert(check_path, "/fw/iosys.lua")
table.insert(check_path, "/fw/client_io.lua")
table.insert(check_path, "/fw/lanes.lua")
table.insert(check_path, "/fw/pack.lua")

while true do
    local key, value = linda:receive(0.01, "new connection")
   -- print("waiting connection")
    if value then

        for _, filename in ipairs(check_path) do
            print("self updating file: ".. filename)
            while true do
                linda:send("vfs_open", filename)
                --vfs:open()
                local file_path, hash
                while true do
                    local key, val = linda:receive(0.001, "vfs_open_res")
                    if val then
                        print("get waiting result")
                        file_path, hash = val[1], val[2]
                        break
                    end
                end

                if file_path then
                    print("get file: " .. file_path, filename)
                    break
                end

                print("hash is: " ..tostring(hash))
                if not hash then
                    print("file does not exist: "..filename)
                    assert(false, "file does not exist! " .. filename)
                    return nil
                end

                print("Try to request hash from server", filename, hash)
                local request = {"EXIST", hash}
                linda:send("request", request)

                local realpath
                while not realpath do
                    local _, value = linda:receive(0.001, "file exist")
                    if value == "not exist" then
                        --not such file on server
                        print("error: file "..filename.." can't be found")
                        return nil
                    else
                        realpath = value
                    end
                end

                --value is the real path
                request = {"GET", realpath, hash}
                linda:send("request", request)
                -- get file
                while true do
                    local _, file_value = linda:receive(0.001, "new file")
                    if file_value then
                        break
                    end
                end

            end
        end
        break
    end
end

--self update complete, tell server
SendIORequest({"RECONNECT", "id"})
local time = os.clock()
while os.clock() - time < 1 do end

print("self update finished")