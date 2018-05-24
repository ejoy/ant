package.path = "../Common/?.lua;../?.lua;" .. package.path  --path for the app
--TODO: find a way to set this
package.remote_search_path = "../?.lua;?.lua" --path for the remote script

local lanes = require "lanes"
if lanes.configure then lanes.configure({with_timers = false, on_state_create = custom_on_state_create}) end
local linda = lanes.linda()
function log(name)
    local tag = "[" .. name .. "] "
    local write = io.write
    return function(fmt, ...)
        write(tag)
        write(string.format(fmt, ...))
        write("\n")
    end
end

local pack = require "pack"
function sendlog(...)
    linda:send("log", pack.pack({...}))
end

local origin_print = print
print = function(...)
    origin_print(...)
    local str = ...
    sendlog(...)
end

local filemanager = require "filemanager"
local file_mgr = filemanager.new()

local bundle_home_dir = ""
local app_home_dir = ""
local g_WindowHandle = nil
local g_Width, g_Height = 0

--overwrite the old io.open function, give it the ability to search resources from server
local origin_open = io.open

local function custom_open(filename, mode, search_local_only)
    --default we don't search local only
    search_local_only = search_local_only or false

    local file = origin_open(filename, mode)
    if not file and not search_local_only then
        --search online
        local request = {"GET", filename}
        linda:send("request", request)

        --TODO file not exist
        --wait here
        while true do
            local key, value = linda:receive(0.05, "new file")
            if value then
                print("received msg", value[1], value[2])
                --put into the id_table and file_table
                file_mgr:AddFileRecord(value[1], value[2])

                file_mgr:WriteDirStructure(bundle_home_dir.."/Documents/dir.txt")
                file_mgr:WriteFilePathData(bundle_home_dir.."/Documents/file.txt")

                print("file name", filename)
                local real_path = file_mgr:GetRealPath(value[2])
                real_path = bundle_home_dir .. "/Documents/" ..real_path
                file = origin_open(real_path, mode)
                print("real path",real_path, file)
                return file
            end
        end
    else
        return file
    end
end

io.open = custom_open

local function remote_searcher (name)
    --local full_path = name..".lua"
    --need to send the package search path
    print("remote requiring", name)
    local request = {"REQUIRE", name, package.remote_search_path}
    linda:send("request", request)

    while true do
        local key, value = linda:receive(0.05, "mem_data")
        if value~=nil then
            print("receive data",type(value))
            return load(value)
        end
    end
end
table.insert(package.searchers, remote_searcher)



--project entrance
local entrance = nil

local lsocket = require "lsocket"
lanes.register("lsocket", lsocket)

local function CreateIOThread(linda, home_dir)
    local client = require "client"
    local c = client.new("127.0.0.1", 8888, linda, home_dir)
    while true do
        c:mainloop(0.1)
        --print("io mainloop updating")
        local resp = c:pop()
        if resp then
            c:process_response(resp)
        end
    end
end

local function run(path)
    if entrance then
        entrance.terminate()
        entrance = nil
    end

    local real_path = file_mgr:GetRealPath(path)
    if real_path then
        real_path = bundle_home_dir .."/Documents/" .. real_path

        entrance = dofile(real_path)
        --must have this function and these variables for init
        entrance.init(g_Width, g_Height, app_home_dir, bundle_home_dir)
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

        print("filename", reverse_path)
        --local rr, vv = pcall(require, reverse_path)
        --print("aabb",rr,vv)
        entrance = require(reverse_path)
        if entrance then
            entrance.init(g_Width, g_Height, app_home_dir, bundle_home_dir)
        end
    end

end

local hw_caps_init = false

local function HandleMsg()
    while true do
        local key, value = linda:receive(0.05, "new file")
        if value then
            --print("received msg", value)
            --put into the id_table and file_table
            file_mgr:AddFileRecord(value[1], value[2])

            file_mgr:WriteDirStructure(bundle_home_dir.."/Documents/dir.txt")
            file_mgr:WriteFilePathData(bundle_home_dir.."/Documents/file.txt")
        else
            break
        end
    end

    while true do
        local key, value = linda:receive(0.05, "run")
        if value then
            --init when need to run something
            if not hw_caps_init then
                local hw_caps = require "render.hardware_caps"
                hw_caps.init()
                hw_caps_init = true
            end

            print("run", value)
            run(value)
        else
            break
        end
    end
end

local bgfx = require "bgfx"
local init_flag = false
function init(window_handle, width, height, app_dir, bundle_dir)
    bundle_home_dir = bundle_dir
    app_home_dir = app_dir

    g_WindowHandle = window_handle
    g_Width = width
    g_Height = height

    file_mgr:ReadDirStructure(bundle_home_dir.."/Documents/dir.txt")
    file_mgr:ReadFilePathData(bundle_home_dir.."/Documents/file.txt")

    bgfx.set_platform_data({nwh = window_handle})
    bgfx.init()


    bgfx.set_debug "T"
    bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

    bgfx.set_view_rect(0, 0, 0, width, height)
    bgfx.reset(width, height, "v")

    init_flag = true

    local client_io = lanes.gen("*",{package = {path = package.path, cpath = package.cpath, preload = package.preload}}, CreateIOThread)(linda, bundle_home_dir)
end

function mainloop()
    if entrance then
        entrance.mainloop()
    end


    HandleMsg()
end

function terminate()
    if entrance then
        entrance.terminate()
    end

    if init_flag then
        bgfx.shutdown()
    end

    --time to save files
    file_mgr:WriteDirStructure(bundle_home_dir.."/Documents/dir.txt")
    file_mgr:WriteFilePathData(bundle_home_dir.."/Documents/file.txt")
end

