---used for initialize structure
local log, pkg_dir, sand_box_dir = ...

package.path = package.path .. ";/fw/?.lua;" .. pkg_dir .. "/fw/?.lua;" .. pkg_dir .. "/?.lua;"
package.path = "../Common/?.lua;./?.lua;../?/?.lua;../?.lua;" .. package.path  --path for the app
--TODO: find a way to set this
--path for the remote script
package.remote_search_path = "/fw/?.lua;/libs/?.lua;/?.lua;./?/?.lua;./libs/asset/?.lua;./libs/ecs/?.lua;./libs/imputmgr/?.lua;"
lanes = require "lanes"
if lanes.configure then lanes.configure({with_timers = false, on_state_create = custom_on_state_create}) end
linda = lanes.linda()


--"cat" means categories for different log
--for now we have "Script" for lua script log
--and "Bgfx" for bgfx log
--"Device" for deivce msg
--project entrance
entrance = nil

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

winfile = require "winfile"
lodepng = require "lodepnglua"

g_WindowHandle = nil
g_Width, g_Height = 0

origin_open = io.open
io.open = function (filename, mode, search_local_only)
    --default we don't search local only
    search_local_only = search_local_only or false

    --vfs not initialized, can only use origin function

    if client_repo then
        print("opening file: ", filename)
        while true do
            --vfs:open()
            local file, hash = client_repo:open(filename)
     --       local file_path, hash
     --       linda:send("vfs_open", filename)
            if file then
                print("get file: "..filename)
                return file
            end

            print("hash is: " ..tostring(hash))
            if not hash then
                print("file does not exist in repo: "..filename)
                break
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
                    break
                else
                    realpath = value
                end
            end

            if not realpath then
                break
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

    print("origin find file: " ..filename)
    local file = origin_open(filename, mode)
    if not file then
        print("can't find file loaclly: "..filename)
    end
    return file
end

local function get_require_search_path(r_name)
--return a table of possible path the file is on
    local search_string = package.remote_search_path
    local search_table = {}

    --separate with ";"
    --"../" not support

    print("require search string", search_string)

    for s_path in string.gmatch(search_string, ".-;") do
        print("get requrie search path: "..s_path)

        local r_path = string.gsub(r_name, "%.", "/")
        s_path = string.gsub(s_path, "?", r_path)
        --get rid of ";" symbol
        s_path = string.gsub(s_path, ";", "")
        table.insert(search_table, s_path)
    end

    return search_table
end

local function remote_searcher(name)
    ---search through package.remote_search_path
    local file_table = get_require_search_path(name)
    for _, v in ipairs(file_table) do
        local r_file = io.open(v, "rb")
        if r_file then
            io.input(r_file)
            local r_data = r_file:read("a")
            r_file:close()
            return load(r_data, "@"..name)
        end
    end

    --required file not exist in the search path
    print("require failed")
    for _, v in ipairs(file_table) do
        print("can't find: "..name.." in " .. v)
    end
    return nil
end
table.insert(package.searchers, remote_searcher)

--require function, will search local files
local origin_require = require
require = function(require_path)
    print("requiring "..require_path)
    if client_repo then
        local file_path = string.gsub(require_path, "%.", "/")
        file_path = file_path .. ".lua"
        local file = client_repo:open(file_path)
        print("search for file path", file_path)
        if file then
            local content = file:read("a")
            print("content", content)
            file:close()

            local err, result = pcall(load(content, "@"..require_path))
            if not err then
                print("require " .. require_path .. " error: " .. result)
                return nil
            else
                return result
            end
        end
    end

    print("use origin require")
    return origin_require(require_path)
end

function CreateIOThread(linda, pkg_dir, sb_dir)
    print("init client repo")
    local vfs = require "firmware.vfs"
    local io_repo = vfs.new(pkg_dir, sb_dir.."/Documents")

    local origin_require = require
    require = function(require_path)
        print("requiring "..require_path)
        if io_repo then
            local file_path = string.gsub(require_path, "%.", "/")
            file_path = file_path .. ".lua"
            local file = io_repo:open(file_path)
            print("search for file path", file_path)
            if file then
                local content = file:read("a")
                print("content", content)
                file:close()

                local err, result = pcall(load(content, "@"..require_path))
                if not err then
                    print("require " .. require_path .. " error: " .. result)
                    return nil
                else
                    return result
                end
            end
        end

        print("use origin require")
        return origin_require(require_path)
    end


    print("create io")
    local client_io = require "fw.client_io"
    print("get required ", client_io)
    local c = client_io.new("127.0.0.1", 8888, linda, pkg_dir, sb_dir, io_repo)

    print("create io finished")
    while true do
        c:mainloop(0.001)
    end
end

local lanes_err
io_thread, lanes_err = lanes.gen("*", CreateIOThread)(linda, pkg_dir, sand_box_dir)
if not io_thread then
    assert(false, "lanes error: ".. lanes_err)
end

function run(path)
    print("run file: "..path)
    if entrance then
        entrance.terminate()
        entrance = nil
    end

    local file = io.open(path, "rb")
    print("open file: "..path)
    io.input(file)
    local entrance_string = file:read("a")
    --print("entrance string: ", entrance_string)
    file:close()

    local res = false
    res, entrance =  pcall(load(entrance_string))

    if res then
        entrance.init(g_WindowHandle, g_Width, g_Height)
    else
        print("entrance script error")
        entrance = nil
    end
end

local bgfx = require "bgfx"
local screenshot_cache_num = 0
function HandleMsg()
    while true do
        local key, value = linda:receive(0.001, "run", "screenshot_req")
        if key == "run" then
            run(value)
        elseif key == "screenshot_req" then
            if entrance then
                bgfx.request_screenshot()
                screenshot_cache_num = screenshot_cache_num + 1
                print("request screenshot: ".. value[2].." num: "..screenshot_cache_num)
            end
        else
            break
        end
    end
end

function HandleCacheScreenShot()
    --if screenshot_cache_num
    --for i = 1, screenshot_cache_num do
    if screenshot_cache_num > 0 then
        local name, width, height, pitch, data = bgfx.get_screenshot()
        if name then
            local size =#data
            print("screenshot size is "..size)
            screenshot_cache_num = screenshot_cache_num - 1
            --compress to png format
            --default is bgra format
            local data_string = lodepng.encode_png(data, width, height);
            print("screenshot encode size ",#data_string)
            linda:send("screenshot", {name, data_string})
        end
    end
end

