package.cpath = "../../../clibs/?.dll;../../../clibs/lib?.so;../../../clibs/?.so;" .. package.cpath
package.path = "../Common/?.lua;../../?/?.lua;../../?.lua;".. package.path

local iup = require "iuplua"
local scintilla = require "scintilla"
local mobiledevice = require "libimobiledevicelua"
local server_framework = require "server_framework"
server_framework:init("127.0.0.1", 8888)


--[[
local log_interface = iup.scintilla{tabtilte = "device log",
                                    MARGINWIDTH0 = "30",	-- line number
                                    STYLEFONT33 = "Consolas",
                                    STYLEFONTSIZE33 = "11",
                                    STYLEVISIBLE33 = "NO",
                                    expand = "YES",
                                    WORDWRAP = "CHAR",
                                    APPENDNEWLINE = "NO",
                                    READONLY = "YES",}

local function append_text(ctrl)
    return function(txt)
        ctrl.READONLY = "NO"
        ctrl.append = txt
        ctrl.READONLY = "YES"
        ctrl.SCROLLBY = ctrl.LINECOUNT
    end
end

local append_error = append_text(log_interface)
--]]
--todo store in a file
local default_proj_dir = "D:/Engine/ant/libs/dev"
--ui layout
local multitext = iup.text{ multiline = "YES", expand = "YES" }

--project directory and run file
local run_file_btn = iup.button{title = "run file"}
local proj_dir_btn = iup.button{title = "select"}
local proj_dir_text = iup.text{expand = "HORIZONTAL", value = default_proj_dir}
server_framework:SetProjectDirectoryPath(default_proj_dir)

local proj_dir_hbox = iup.hbox{run_file_btn, proj_dir_btn, proj_dir_text}
local main_vbox = iup.vbox{multitext, proj_dir_hbox}

--device select and connect/disconnect
local device_list = iup.list{expand = "YES", spacing = 1}
local device_frame = iup.frame{device_list, title = "device(s)"}
local connect_list = iup.list{expand = "YES"}
local connect_frame = iup.frame{connect_list, title = "connected"}

local connect_btn = iup.button{title = "connect"}
local disconnect_btn = iup.button{title = "disconnect"}
local open_close_simpad_btn = iup.button{title = "open/close sim pad"}
local simpad_dlg = nil

local connect_btn_hbox = iup.hbox{connect_btn, disconnect_btn, open_close_simpad_btn}
local device_vbox = iup.vbox{device_frame, connect_frame, connect_btn_hbox}

local main_split = iup.split{main_vbox, device_vbox}

--call back
function proj_dir_btn:action()
    local filedlg = iup.filedlg{dialogtype = "DIR", title = "select project directory", directory = proj_dir_text.text}
    filedlg:popup(iup.ANYWHERE, iup.ANYWHERE)

    local status = filedlg.status

    if status ~= "-1" then
        --todo
        local slash_string = string.gsub(filedlg.value, "\\", "/");

        proj_dir_text.value = slash_string
        server_framework:SetProjectDirectoryPath(slash_string)
    end

    filedlg:destroy()
end

function run_file_btn:action()
    local filedlg = iup.filedlg{dialogtype = "OPEN", title = "run file", filter = "*.lua", filterinfo = "Lua files", directory = proj_dir_text.value}
    filedlg:popup(iup.ANYWHERE, iup.ANYWHERE)

    local status = filedlg.status

    if status ~= "-1" then
        local file_value = string.gsub(filedlg.value, "\\", "/")

        server_framework:HandleCommand("all", "RUN", file_value)
    end

    filedlg:destroy()
end

function connect_btn:action()
    local select_idx = device_list.value

    --none selected
    if select_idx == 0 then
        return
    end

    local udid = device_list[select_idx]
    server_framework:HandleCommand(udid, "CONNECT")
end


function disconnect_btn:action()
    local select_idx = connect_list.value

    --none selected
    if select_idx == 0 then
        return
    end

    local udid = connect_list[select_idx]
    server_framework:HandleCommand(udid, "DISCONNECT")
end

function open_close_simpad_btn:action()
    if simpad_dlg then
        simpad_dlg:destroy()
        simpad_dlg = nil
    else

        --local dlg = iup.dialog{main_split, title = "ANT ENGINE", size = "HALFxHALF"}
        local canvas = iup.canvas{rastersize = "640x480", bgcolor = "255 0 128 255"}
        simpad_dlg = iup.dialog{canvas, title = "sim pad", size = "QUARTERxQUARTER"}

        simpad_dlg:showxy(iup.ANYWHERE,iup.ANYWHERE)
        simpad_dlg.usersize = nil
    end
end

local function HandleResponse(resp_table)
    for _,v in ipairs(resp_table) do
        if type(v) == "string" then
            --this is just log
            --for now, just show on the multitext
            multitext.value = multitext.value .. "\n" .. v
            --print("linecount", multitext.linecount)
            local pos = iup.TextConvertLinColToPos(multitext,  multitext.linecount, 0)
            multitext.caretpos = pos
            multitext.scrolltopos = pos

            --multitext.scrolltopos =multitext.linecount
            --append_error(v.."\n")

        elseif type(v) == "table" then
            if v[1] == "device" then
                --device connection and disconnection
                if v[2] == 1 then
                    --connected
                    local idx = connect_list.count
                    connect_list[idx+1] = v[3]
                else
                    --disconnected
                    local list_count = connect_list.count
                    for i = 1, list_count do
                        if connect_list[i] == v[3] then
                            --remove the item
                            for j = i, list_count-1 do
                                connect_list[j] = connect_list[j+1]
                            end
                            connect_list[list_count] = nil
                            break
                        end
                    end
                end
            else
                print("resp " .. v[1] .. " not support yet")
            end
        else
            print("resp type: " .. type(v) .. " not support yet")
        end
    end
end

--return a table
local devices = mobiledevice.GetDevices()
--init connect devices
for i = 1, #devices do
    device_list[i] = devices[i]
end


local dlg = iup.dialog{main_split, title = "ANT ENGINE", size = "HALFxHALF"}

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

-- to be able to run this script inside another context
while true do
    local msg = iup.LoopStep()
    if msg == iup.CLOSE then
        break
    end

    server_framework:update()
    local resp_table = server_framework:RecvResponse()
    HandleResponse(resp_table)
    --handle response here

end

iup.Close()