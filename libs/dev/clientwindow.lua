package.remote_searchpath = "ServerFiles"
package.cpath = "../../clibs/?.dll"
package.path = "../?/?.lua;" .. package.path
local lanes = require "lanes"
if lanes.configure then lanes.configure() end
local linda = lanes.linda()

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
local io = lanes.gen("*", CreateIOThread)(linda)

local function remote_searcher (name)
    local full_path = package.remote_searchpath .. "/" ..name..".lua"
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

--test command
local button_GET = iup.button{title = "GET", action = send_get_cmd}
local button_LIST = iup.button{title = "LIST", action = send_list_cmd}
local button_PING = iup.button{title = "PING", action = send_ping_cmd}
local button_EXIT = iup.button{title = "EXIT", action = btn_exit_cb}

local window_label = iup.label{title = "Client command"}

local hbox = iup.hbox{button_GET, button_LIST, button_PING, button_EXIT}

local vbox = iup.vbox{window_label, text_line, hbox}

local dlg = iup.dialog{
    vbox, title = "Hello World",
    margin = "4x4",
    size = "320x120"
}

local remotestuff = require "remotestuff"
print("remotestuff", remotestuff)
dlg:showxy(iup.CENTER, iup.CENTER)

--logic thread
if (iup.MainLoopLevel() == 0) then
    remotestuff.run()
    iup.MainLoop()
    iup.Close()
end
