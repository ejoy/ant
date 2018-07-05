package.cpath = "../../../clibs/?.dll"
package.path = "../Common/?.lua;../../?.lua;../../?/?.lua;".. package.path


local debugger = require 'new-debugger'
local lanes = require "lanes"
if lanes.configure then lanes.configure() end
local linda = lanes.linda()

local filemanager = require "filemanager"
local file_mgr = filemanager.new()
--read here
file_mgr:ReadDirStructure("dir.txt")
file_mgr:ReadFilePathData("file.txt")

--io thread
local function CreateIOThread(linda)
    local client = require "client"
    local c = client.new("127.0.0.1", 8888, linda)
    --c:send("GET", "ServerFiles/building.mp4")
    while true do
        c:mainloop(1)
        local resp = c:pop()
        if resp then
            c:process_response(resp)
        end
    end
end
local client_io = lanes.gen("*", CreateIOThread)(linda)

local function CreateDbgThread()
    package.path = "../../?.lua;".. package.path
    local debugger = require 'new-debugger'
    local DbgUpdate = debugger:initialize()
    while true do
        DbgUpdate()
    end
end
lanes.gen("*", CreateDbgThread)()

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

--this will be a interface for the client end
local iup = require "iuplua"
local text_line = iup.text{multiline = "NO", expand = "YES"}

local function btn_exit_cb(self)
    return iup.CLOSE
end

local function send_ping_cmd()
    print("PING")
    local request = {"PING"}

    linda:send("request", request)
end

local function send_get_cmd()
    local request = {"GET", text_line.value}
    print("GET")

    linda:send("request", request)
end

local function send_list_cmd()
    local request = {"LIST", text_line.value}
    print("LIST")

    linda:send("request", request)
end

local function btn_open_cmd()
    local real_path = file_mgr:GetRealPath(text_line.value)
    real_path = "Files/" .. real_path
    print("real path", real_path)
    local file = io.open(real_path, "r")
    if not file then
        print("file not found")
        return
    end

    io.input(file)
    local file_data = file:read("*a")
    print(file_data)
    file:close()
end

local function send_exist_cmd()
    local request = {"EXIST", text_line.value}
    linda:send("request", request)
end

--test command
local button_GET = iup.button{title = "GET", action = send_get_cmd}
local button_LIST = iup.button{title = "LIST", action = send_list_cmd}
local button_PING = iup.button{title = "PING", action = send_ping_cmd}
local button_EXIST = iup.button{title = "EXIST", action = send_exist_cmd}
local button_EXIT = iup.button{title = "EXIT", action = btn_exit_cb}
local button_OPEN = iup.button{title = "OPEN", action = btn_open_cmd}
local window_label = iup.label{title = "Client command"}

local hbox = iup.hbox{button_GET, button_LIST, button_PING, button_EXIST, button_EXIT, button_OPEN}

local vbox = iup.vbox{window_label, text_line, hbox}

local dlg = iup.dialog{
    vbox, title = "Hello World",
    margin = "4x4",
    size = "320x120"
}

dlg:showxy(iup.CENTER, iup.CENTER)

local function HandleMsg()
    local key, value = linda:receive(0.01, "new file")
    if value then
        --print("received msg", value)
        --put into the id_table and file_table
        file_mgr:AddFileRecord(value[1], value[2])

        file_mgr:WriteDirStructure("dir.txt")
        file_mgr:WriteFilePathData("file.txt")
    end
end

debugger:start()

--logic thread
if (iup.MainLoopLevel() == 0) then
    --iup.MainLoop()
    while true do
        debugger:update()
        HandleMsg()
        --remotestuff.run()
        local msg = iup.LoopStep()
        if msg == iup.CLOSE then
            break
        end
    end
    iup.Close()
end

--after closing the program, update the file
file_mgr:WriteDirStructure("dir.txt")
file_mgr:WriteFilePathData("file.txt")