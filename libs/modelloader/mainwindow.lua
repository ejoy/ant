dofile "libs/init.lua"
local elog = require "editor.log"
local ecs = require "ecs"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local bgfx = require "bgfx"
local rhwi = require "render.hardware_interface"
local scene = require "scene.util"
local assimplua = require"assimplua"
local render_mesh = require "modelloader.rendermesh"
local path = require "filesystem.path"
local fs_util = require "filesystem.util"


if not static_link_iup then
    require "iupluaimglib"
    require "iuplua"
    require "scintilla"
end

local filetree = require "modelloader.filetree"
--先测试bgfx的使用
--画布,渲染模型场景
local fb_width, fb_height = 1024, 768
local canvas = iup.canvas{
    rastersize = fb_width .. "x" .. fb_height
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
            --local out_path = string.gsub(in_path, ".fbx", function(s) return ".bin" end)
            local out_path = path.replace_ext(in_path, "bin")
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
local input_queue = inputmgr.queue(mapiup, canvas)

--初始化系统
local function init()
    rhwi.init(iup.GetAttributeData(canvas,"HWND"), fb_width, fb_height)
    local module_description_file = "mem://model_main_window.module"
    fs_util.write_to_file(module_description_file, [[modules = {"libs/modelloader/renderworld.lua"}]])
    scene.start_new_world(input_queue, fb_width, fb_height, module_description_file)
end

dlg:showxy(iup.CENTER, iup.CENTER)
dlg.usersize = nil

init()

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
    iup.MainLoop()
    iup.Close()
    bgfx.shutdown()
end