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
local winfile = require "winfile"

require "iupluaimglib"
require "iuplua"
require "scintilla"


local filetree = require "modelloader.filetree"

local fb_width, fb_height = 1024, 768
local canvas = iup.canvas{
    rastersize = fb_width .. "x" .. fb_height
}

--open bin file
local item_open = iup.item{title = "Open"}
--export fbx to bin
local item_export = iup.item{title = "Export"}  --将fbx导出为bin文件
--export all fbx file under directory to bin
local item_export_dir = iup.item{title = "Export Dir"}

local item_exit = iup.item{title = "Exit"}

local item_test_parser = iup.item{title = "test parser"}

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
            --local out_path = string.gsub(in_path, ".fbx", function(s) return ".bin" end)
            local out_path = path.replace_ext(in_path, "bin")
            assimplua.assimp_import(in_path, out_path)

            print("Export file to: " .. out_path)

            render_mesh:InitRenderContext(out_path)
        end
    end

    export_dlg:destroy()
end

function item_export_dir:action()
    local export_dir_dlg = iup.filedlg{
        dialogtype = "DIR",
        parentdialog = iup.GetDialog(self),
    }

    export_dir_dlg:popup(iup.ANYWHERE, iup.ANYWHERE)

    if(tonumber(export_dir_dlg.status) ~= -1) then
        local in_path = export_dir_dlg.value

        if in_path then
            local test_file = nil
            for file in winfile.dir(in_path) do
                --print("found file:", path.ext(file))
                if file then
                    print("export file ", file)
                    local file_ext = path.ext(file)

                    if file_ext and string.lower(file_ext) == "fbx" then
                        print("found file:", file)
                        local in_file = in_path .. "/" .. file
                        local out_file = path.replace_ext(in_file, "bin")
                        assimplua.assimp_import(in_file, out_file)

                        print("Export file to: ".. out_file)
                        test_file = out_file
                    end
                end
            end

            if test_file then
                --render_mesh:initRenderContext(test_file)
            end
        end

    end
end

function item_exit:action()
    return iup.CLOSE
end


function item_test_parser:action()




end

file_menu = iup.menu{item_open, item_export, item_export_dir, iup.separator{}, item_exit, item_test_parser}
sub_menu = iup.submenu{file_menu, title = "File"}
main_meun = iup.menu{sub_menu}

local tree = filetree.tree

local dlg = iup.dialog{
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