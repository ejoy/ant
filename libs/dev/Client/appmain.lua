package.cpath = "../../../clibs/?.dll;" .. package.cpath
package.path = "../Common/?.lua;../../?/?.lua;".. package.path
local hw_caps = require "render.hardware_caps"

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

local function remote_searcher (name)
    local full_path = name..".lua"
    local request = {"OPEN", full_path}
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

local filemanager = require "Common.filemanager"
local file_mgr = filemanager.new()

local bundle_home_dir = nil
local app_home_dir = nil
local g_WindowHandle = nil
local g_Width, g_Height = 0

--project entrance
local entrance = nil

local lsocket = require "lsocket"
lanes.register("lsocket", lsocket)

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
        entrance.init(g_WindowHandle, g_Width, g_Height, app_home_dir, bundle_home_dir)
    end

end

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
            --print("run", value)
            run(value)
        else
            break
        end
    end
end

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

function init(window_handle, width, height, app_dir, bundle_dir)
    hw_caps.init()
    bundle_home_dir = bundle_dir
    app_home_dir = app_dir

    g_WindowHandle = window_handle
    g_Width = width
    g_Height = height

    file_mgr:ReadDirStructure(bundle_home_dir.."/Documents/dir.txt")
    file_mgr:ReadFilePathData(bundle_home_dir.."/Documents/file.txt")

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
    --time to save files
    file_mgr:WriteDirStructure(bundle_home_dir.."/Documents/dir.txt")
    file_mgr:WriteFilePathData(bundle_home_dir.."/Documents/file.txt")
end

function sendlog(str)
    linda:send("log", str)
end

