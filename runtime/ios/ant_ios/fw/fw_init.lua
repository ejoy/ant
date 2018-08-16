---used for initialize structure
local log, cfuncs, app_dir = ...
f_table = cfuncs()

f_table.preloadc()

package.path = package.path .. ";" .. app_dir .. "/fw/?.lua;" .. app_dir .. "/?.lua;"
package.path = "../Common/?.lua;./?.lua;../?/?.lua;../?.lua;" .. package.path  --path for the app
--TODO: find a way to set this
--path for the remote script
package.remote_search_path = "../?.lua;./?.lua;../?/?.lua;asset/?.lua;?/?.lua;ecs/?.lua;imputmgr/?.lua"
lanes = require "lanes"
if lanes.configure then lanes.configure({with_timers = false, on_state_create = custom_on_state_create}) end
linda = lanes.linda()

--"cat" means categories for different log
--for now we have "Script" for lua script log
--and "Bgfx" for bgfx log
--"Device" for deivce msg
--project entrance
entrance = nil
client_repo = false   -- vfs repo
local origin_print = print
function sendlog(cat, ...)
    linda:send("log", {cat, ...})
    --origin_print(cat, ...)
end

function app_log( ...)

    local output_log_string = {}
    for _, v in ipairs({...}) do
        table.insert(output_log_string, tostring(v))
    end

  --  sendlog("Script", table.unpack(output_log_string))
end

print = function(...)
    origin_print(...)
    --print will have a priority 1
    app_log(...)
end

function compile_shader(srcpath, outfile)
    print("compile shader path: "..srcpath)
    linda:send("request", {"COMPILE_SHADER", srcpath})

    while true do
        local key, value = linda:receive(0.01, "shader_compiled")
        if value then
            break
        end
    end

    return true
end

winfile = require "winfile"
lodepng = require "lodepnglua"

sand_box_dir = nil
package_dir = nil
g_WindowHandle = nil
g_Width, g_Height = 0

local origin_open = io.open
io.open = function (filename, mode, search_local_only)
    --default we don't search local only
    search_local_only = search_local_only or false

    --vfs not initialized, can only use origin function
    if not client_repo then
        return origin_open(filename, mode)
    end
    --file may be in the bundle
    --for now don't cache lua files
    print("opening file: ", filename)
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
            return origin_open(file_path, mode)
        end

        print("hash is: " ..tostring(hash))
        assert(hash, "vfs system error: no file and no hash: " .. filename)

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

local origin_loadfile = loadfile
loadfile = function(file_path)
    --[[
    local file = origin_loadfile(file_path)
    if file then
        return file
    end

    file = io.open(file_path, "r")
    if file then
        io.input(file)
        local file_string = file:read("*a")
        file:close()
        return load(file_string)
    else
        print("require file error: "..name)
        return nil
    end
    --]]
end

local function remote_searcher (name)
    --local full_path = name..".lua"
    --need to send the package search path
    print("remote requiring ".. name)
    local request = {"REQUIRE", name, package.remote_search_path}
    linda:send("request", request)

    while true do
        local key, value = linda:receive(0.001, "mem_data")
        if value then
            return load(value, "@"..name)
        end
    end
end
table.insert(package.searchers, remote_searcher)

local lsocket = require "lsocket"
lanes.register("lsocket", lsocket)

function CreateIOThread(linda, pkg_dir, sb_dir)

    local client_io = require "client_io"
    local c = client_io.new("127.0.0.1", 8888, linda, pkg_dir, sb_dir)

    origin_print("create io")
    while true do
        c:mainloop(0.001)
    end
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
    print("entrance string: ", entrance_string)
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

local function init_lua_search_path(app_dir)
    package.path = package.path .. ";" .. app_dir .. "/libs/?.lua;" .. app_dir .. "/libs/?/?.lua;" .. app_dir .. "/libs/ecs/?.lua;"

    require "common/import"
    require "common/log"
    require "filesystem"

    print_r = require "common/print_r"

    function dprint(...) print(...) end
end

file_exist_cache = {}