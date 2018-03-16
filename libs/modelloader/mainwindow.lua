dofile "libs/init.lua"
local elog = require "editor.log"
local ecs = require "ecs"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local db = require "debugger"
local task = require "editor.task"
local bgfx = require "bgfx"
local hw_caps = require "render.hardware_caps"
local assimplua = require"assimplua"
local render_mesh = require "modelloader.rendermesh"

require "iupluaimglib"
require "iuplua"
require "scintilla"

local filetree = require "modelloader.filetree"
--先测试bgfx的使用
--画布,渲染模型场景
local canvas = iup.canvas{
    rastersize = "1024x768"
}

--菜单栏,用于基本文件操作
local item_open = iup.item{title = "Open"}      --打开bin文件
local item_export = iup.item{title = "Export"}  --将fbx导出为bin文件
local item_exit = iup.item{title = "Exit"}      --退出窗口

function item_open:action()
    local file_dlg = iup.filedlg{
        dialogtype = "OPEN",
        filter = "*.bin",
        filterinfo = "BIN Files",
        parentdialog = iup.GetDialog(self),
    }

    file_dlg:popup(iup.CENTERPARENT, iup.CENTERPARENT)

    if(tonumber(file_dlg.status) ~= -1) then
        local filename = file_dlg.value
        if(filename) then
            print("Open file: " .. filename)
            render_mesh:InitRenderContext(filename)

        end
    end

    file_dlg:destroy()
end

function item_export:action()
    local export_dlg = iup.filedlg{
        dialogtype = "OPEN",
        filter = "*.fbx",
        filterinfo = "FBX Files",
        parentdialog=iup.GetDialog(self),
    }

    export_dlg:popup(iup.CENTERPARENT, iup.CENTERPARENT)

    if(tonumber(export_dlg.status) ~= -1) then
        local in_path = export_dlg.value
        if(in_path) then
            --导出路径暂时不可自定义,放在导入目录里面
            local out_path = string.gsub(in_path, ".fbx", function(s) return ".bin" end)
            assimplua.assimp_import(in_path, out_path)

            print("Export file to: " .. out_path)

            render_mesh:InitRenderContext(out_path)
        end
    end

    export_dlg:destroy()
end



function item_exit:action()
    return iup.CLOSE
end

file_menu = iup.menu{item_open, item_export, iup.separator{}, item_exit}
sub_menu = iup.submenu{file_menu, title = "File"}
main_meun = iup.menu{sub_menu}

local tree = filetree.tree
--主界面
local dlg = iup.dialog{
    --分隔成两部分
    iup.split
    {
        iup.split
        {
            tree.view,
            canvas,
            SHOWGRIP = "NO"
        }
        ,
        elog.window,
        SHOWGRIP = "NO",
    },

    margin = "4x4",
    size = "HALFxHALF",
    shrink = "Yes",
    title = "Model Loader",
    menu = main_meun,
}


--注册设备输入
local input_queue = inputmgr.queue(mapiup)
input_queue:register_iup(canvas)

local world

--初始化系统
local function init()
    --初始化bgfx
    --todo：深入研究bgfx-lua binding
    local function bgfx_init()
        local args = {
            nwh = iup.GetAttributeData(canvas,"HWND"),
            renderer = nil	-- use default
        }
        bgfx.set_platform_data(args)
        bgfx.init(args.renderer)

        hw_caps.init()
    end
    bgfx_init()


    --在ecs系统中添加新的世界
    --todo: 深入研究ecs这段的含义
    world = ecs.new_world {
        modules = {
            assert(loadfile "libs/modelloader/renderworld.lua"),
            --[[
            assert(loadfile "libs/inputmgr/message_system.lua"),
            assert(loadfile "libs/render/add_entity_system.lua"),
            assert(loadfile "libs/render/math3d/math_component.lua"),
            assert(loadfile "libs/render/material/material_component.lua"),
            assert(loadfile "libs/render/mesh_component.lua"),
            assert(loadfile "libs/render/viewport_component.lua"),
            assert(loadfile "libs/render/camera/camera_component.lua"),
            assert(loadfile "libs/render/camera/camera_system.lua"),
            assert(loadfile "libs/render/camera/camera_controller.lua"),
            assert(loadfile "libs/render/renderpipeline.lua"),
            --]]
        },
        args = { mq = input_queue },
    }

    --将新的系统加入给task管理,后面是回调
    task.loop(world.update,
            function ()
                local trace = db.traceback()
                elog.print(trace)
                elog.active_error()
            end)
    --]]]
end

--画布大小改变
function canvas:resize_cb(w, h)
    if init then
        init(self)
        init = nil
    end

    input_queue:push("resize", w, h)
end

dlg:showxy(iup.CENTER, iup.CENTER)
dlg.usersize = nil

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
    iup.MainLoop()
    iup.Close()
    bgfx.shutdown()
end