dofile("libs/init.lua")

package.cpath = "clibs/?.dll; clibs/lib?.so; clibs/?.so;" .. package.cpath
package.path = "libs/dev/Common/?.lua;libs/dev/Server/?.lua;libs/dev/?.lua;".. package.path

local iup = require "iuplua"
local mobiledevice = require "libimobiledevicelua"
local server_framework = require "server_framework"
server_framework:init("127.0.0.1", 8888)

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

local connect_btn_hbox = iup.hbox{connect_btn, disconnect_btn, open_close_simpad_btn}
local device_vbox = iup.vbox{device_frame, connect_frame, connect_btn_hbox}

local main_split = iup.split{main_vbox, device_vbox}

--simpad related stuff
local bgfx = require "bgfx"
local rhwi = require "render.hardware_interface"
local shader_mgr = require "render.resources.shader_mgr"
local nk = require "bgfx.nuklear"

local UI_VIEW = 0
local width = 420
local height = 360
local simpad_canvas = iup.canvas{rastersize = "420x360", bgcolor = "255 0 123"}
local simpad_dlg = iup.dialog{simpad_canvas, title = "sim pad", size = "420x360"}
local simpad_show = false


local function loadtexture(texname,info)
    local image = nk.loadImage( texname );

    return image
end

local nkimage = nil

local function init_bgfx()
    rhwi.init(iup.GetAttributeData(simpad_canvas, "HWND"), width, height)

    nk.init{
        view = UI_VIEW,
        width = width,
        height = height,
        decl = bgfx.vertex_decl {
            { "POSITION", 2, "FLOAT" },
            { "TEXCOORD0", 2, "FLOAT" },
            { "COLOR0", 4, "UINT8", true },
        },
        texture = "s_texColor",
        state = bgfx.make_state {
            WRITE_MASK = "RGBA",
            BLEND = "ALPHA",
        },
        prog = shader_mgr.programLoad("ui/vs_nuklear_texture.sc",
                "ui/fs_nuklear_texture.sc"),
    }

    local nkatlas = loadtexture( "assets/textures/ScreenShot.png") --button.png" )

    nkimage = nk.makeImage( nkatlas.handle,nkatlas.w,nkatlas.h)  -- make from outside id ,w,h
--    nkim   = nk.makeImageMem( data,w,h)
    print("---id("..nkimage.handle..")"..' w'..nkimage.w..' h'..nkimage.h)
   -- nk.image( nkimage )  --test nested lua

    bgfx.set_view_clear(UI_VIEW, "C", 0x303030ff, 1, 0)

end

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

function simpad_dlg:close_cb()
    simpad_show = false
end

function open_close_simpad_btn:action()
    if simpad_show then
        simpad_dlg:hide()

        simpad_show = false
    else
        server_framework:HandleCommand("all", "SCREENSHOT")

        simpad_dlg:showxy(iup.ANYWHERE, iup.ANYWHERE)
        simpad_dlg.usersize = nil

        if init_bgfx then
            init_bgfx()
            init_bgfx = nil
        end

        simpad_show = true
    end
end

local lodepng = require "lodepnglua"
local pack = require "pack"
local function HandleResponse(resp_table)

    for _,v in ipairs(resp_table) do
        if type(v) == "string" then
            --this is just log
            --for now, just show on the multitext
            --need to unpack twice, because the text is packed too
            local log_pack = pack.unpack(v)
            if log_pack then
                for _, log_string in pairs(log_pack) do
                    if log_string then

                        local log_line = pack.unpack(log_string)
                        for _, log_line_value in pairs(log_line) do

                            multitext.value = multitext.value .. "\n" .. log_line_value
                        end

                    end
                end
            end

            local pos = iup.TextConvertLinColToPos(multitext,  multitext.linecount, 0)
            multitext.caretpos = pos
            multitext.scrolltopos = pos

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
            elseif v[1] == "screenshot" then
                local screenshot = v[2]
                local name = screenshot[1]
                local data = screenshot[2]

                --decompress it and show the image
                local data, width, height = lodepng.decode_png(data)
                assert(width > 0 and height > 0)

                print("get screenshot", width, height, #data)

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

local function UpdateSimpad()

    if nk.windowBegin( "Test","Test Window ui", 0, 0, 720, 460,
            "border", "movable", "title", "scalable",'scrollbar') then
        --image(nkimage)

        nk.layoutRow('dynamic',310,{0.15,0.7,0.15} )
        nk.spacing(1)
        nk.image( nkimage )
    end
    nk.windowEnd()
    nk.update()

    bgfx.frame()
end

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

    if simpad_dlg and simpad_show then
        UpdateSimpad()
    end

end

iup.Close()