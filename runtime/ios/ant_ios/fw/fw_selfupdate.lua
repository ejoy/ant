---used for initialize structure
local log, cfuncs, pkg_dir, sb_dir = ...
f_table = cfuncs()

f_table.preloadc()

package.path = package.path .. ";" .. pkg_dir .. "/fw/?.lua;".. pkg_dir .. "/?.lua;"
package.path = "../Common/?.lua;./?.lua;../?/?.lua;../?.lua;" .. package.path  --path for the app
--TODO: find a way to set this
--path for the remote script
package.remote_search_path = "/libs/?.lua;/?.lua;./?/?.lua;./libs/asset/?.lua;./libs/ecs/?.lua;./libs/imputmgr/?.lua;"
lanes = require "lanes"
if lanes.configure then lanes.configure({with_timers = false, on_state_create = custom_on_state_create}) end
linda = lanes.linda()

origin_print = print
function sendlog(cat, ...)
    linda:send("log", {cat, os.clock(),...})
    --origin_print(cat, ...)
end

function app_log( ...)

    local output_log_string = {}
    for _, v in ipairs({...}) do
        table.insert(output_log_string, tostring(v))
    end

    sendlog("Script", table.unpack(output_log_string))
end

print = function(...)
    origin_print(...)
    --print will have a priority 1
    app_log(...)
end

function CreateIOThread(linda, pkg_dir, sb_dir)
    local vfs = require "firmware.vfs"
    local io_repo = vfs.new(pkg_dir, sb_dir.."/Documents")

    local client_io = require "client_io"
    local c = client_io.new("127.0.0.1", 8888, linda, pkg_dir, sb_dir, io_repo)
    while true do
        c:mainloop(0.001)
    end
end

local client_io = lanes.gen("*", CreateIOThread)(linda, pkg_dir, sb_dir)

local check_path = {}
--todo: self update it self, then self update again?
--put these file to local repo
table.insert(check_path, "/fw/fw_init.lua")
table.insert(check_path, "/fw/fw_io.lua")
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
                        --file_value should be local address
                        --client_repo:write should be called in io thread
                        print("get new file: " .. realpath)
                        break
                    end
                end

            end
        end
        break
    end
end
