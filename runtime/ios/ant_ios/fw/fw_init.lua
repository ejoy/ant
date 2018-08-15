---used for initialize structure
local log, cfuncs, app_dir = ...
f_table = cfuncs()

f_table.preloadc()

package.path = package.path .. ";" .. app_dir .. "/?.lua"
package.path = "../Common/?.lua;./?.lua;../?/?.lua;../?.lua;" .. package.path  --path for the app
--TODO: find a way to set this
--path for the remote script
package.remote_search_path = "../?.lua;?.lua;../?/?.lua;asset/?.lua;?/?.lua;ecs/?.lua;imputmgr/?.lua"
lanes = require "lanes"
if lanes.configure then lanes.configure({with_timers = false, on_state_create = custom_on_state_create}) end
linda = lanes.linda()

--"cat" means categories for different log
--for now we have "Script" for lua script log
--and "Bgfx" for bgfx log
--"Device" for deivce msg
--project entrance
entrance = nil
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

filemanager = require "filemanager"
file_mgr = filemanager.new()

winfile = require "winfile"
lodepng = require "lodepnglua"

sand_box_dir = nil
package_dir = nil
g_WindowHandle = nil
g_Width, g_Height = 0

--overwrite the old io.open function, give it the ability to search resources from server

local origin_open = io.open

io.open = function (filename, mode, search_local_only)
    --default we don't search local only
    search_local_only = search_local_only or false

    local file = origin_open(filename, mode)

    --file may be in the bundle
    --for now don't cache lua files
    if not file then
        print("searching file in bundle: "..filename)
        --find out if it exist locally
        local local_path = file_mgr:GetRealPath(filename)
        if local_path then
            --check exist, mainly for camparing hash
            local file_exist = winfile.exist(filename)
            if file_exist then
                print("bundle real path for: "..filename.." is "..local_path)
                local_path = sand_box_dir .. "/Documents/" ..local_path
                file = origin_open(local_path, mode)

                return file
            end
        end
    end

    --file may be in the remote server
    if not file and not search_local_only then
        print("searching file in server: "..filename)
        --search online
        local request = {"GET", filename}
        linda:send("request", request)

        --TODO file not exist
        --wait here
        while true do
            local _, value = linda:receive(0.001, "new file")
            if value then
                print("received msg", filename)

                --put into the id_table and file_table
                file_mgr:AddFileRecord(value[1], value[2])
                print("add file recode: "..value[1] .. " and "..value[2])
                file_mgr:WriteDirStructure(sand_box_dir.."/Documents/dir.txt")
                file_mgr:WriteFilePathData(sand_box_dir.."/Documents/file.txt")

                print("file name", filename)
                local real_path = file_mgr:GetRealPath(value[2])
                real_path = sand_box_dir .. "/Documents/" .. real_path
                file = origin_open(real_path, mode)

                print("server real file path: "..real_path)
                return file
            end
        end
    else
        print("use origin open: "..filename)
        return file
    end
end

local origin_loadfile = loadfile
loadfile = function(file_path)
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

function CreateIOThread(linda, sb_dir)

    local client_io = require "client_io"
    local c = client_io.new("127.0.0.1", 8888, linda, sb_dir)

    origin_print("create io")
    while true do
        c:mainloop(0.001)
    end
end

function run(path)
    print("run file"..path)
    if entrance then
        entrance.terminate()
        entrance = nil
    end


    if winfile.exist(path, true) then
        local real_path = file_mgr:GetRealPath(path)
        if real_path then
            real_path = sand_box_dir .."/Documents/" .. real_path

            entrance = dofile(real_path)
            --must have this function and these variables for init
            entrance.init(g_WindowHandle, g_Width, g_Height, package_dir, sand_box_dir)
        else
            --not in local, need require from distance
            --get file name
            local reverse_path = string.reverse(path)
            local slash_pos = string.find(reverse_path, "/")
            if slash_pos then
                reverse_path = string.sub(reverse_path, 1, slash_pos - 1)
            end
            reverse_path = string.reverse(reverse_path)
            --get rid of .lua
            reverse_path = string.sub(reverse_path, 1, -5)

            entrance = require(reverse_path)
            if entrance then
                entrance.init(g_WindowHandle, g_Width, g_Height, package_dir, sand)
            end
        end
    end
end

local bgfx = require "bgfx"
local screenshot_cache_num = 0
function HandleMsg()
    while true do
        local key, value = linda:receive(0.001, "new file", "run", "screenshot_req")
        if key == "new file" then
            --print("received msg", value)
            --put into the id_table and file_table
            file_mgr:AddFileRecord(value[1], value[2])

            file_mgr:WriteDirStructure(sand_box_dir.."/Documents/dir.txt")
            file_mgr:WriteFilePathData(sand_box_dir.."/Documents/file.txt")

        elseif key == "run" then
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