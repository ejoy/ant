--luacheck: globals iup import
require "iuplua"
iup.SetGlobal("GLOBALLAYOUTDLGKEY", "Yes");

local bgfx          = require "bgfx"

local editor        = import_package "ant.editor"
local inputmgr      = import_package "ant.inputmgr"
local iupcontrols   = import_package "ant.iupcontrols"
local rhwi          = import_package "ant.render".hardware_interface
local elog          = iupcontrols.logview
local tree = iupcontrols.tree
local fs_hierarchy = require "fs_hierarchy"
local asset_view = require "asset_view"
local SceneControl = require "scene_controll"
local mapiup        = editor.mapiup
local editor_mainwindow = {}
editor_mainwindow.__index = editor_mainwindow
local math = require "math"



local nodes = {}
function editor_mainwindow:build_window(fbw, fbh)
    
    -- self.tree = tree.new({SHOWTOGGLE = "YES"})
    self:build_menu()
    
    self.fs_hierarchy = fs_hierarchy.new {
        rastersize = math.floor(fbw*0.25) .. "x" .. math.floor(fbh - fbw*0.25-50)
    }
    self.asset_view = asset_view.new {
        rastersize = math.floor(fbw*0.25) .. "x" .. math.floor(fbw*0.25)
    }

    
    self.canvas = iup.canvas {
        rastersize = fbw*0.7 .. "x" .. fbh*0.7
    }

    self.input_queue = inputmgr.queue()
    mapiup(self.input_queue, self.canvas)

    self.scene_control = SceneControl.new(self.menu,self.input_queue)
    
    self.dlg = iup.dialog {
        iup.split {
            iup.split {
                self.fs_hierarchy:get_view(),
                self.asset_view:get_view(),
                showgrip = "NO",
                ORIENTATION="HORIZONTAL",
            },
            iup.split {
                self.canvas,
                elog.window,
                ORIENTATION="HORIZONTAL",
                showgrip = "NO",
            },
            showgrip = "NO",
            ORIENTATION="VERTICAL"
        },
        menu = self.menu:get_view(),
        title = "Editor",
        rastersize = string.format("%dx%d",math.floor(fbw),math.floor(fbh)),
        shrink="YES",    -- logger box should be allow shrink
    }

    
end

function editor_mainwindow:build_menu()
    local MenuBar          = iupcontrols.menubar
    self.menu = MenuBar.new({{"File",iup.menu({})},
                            {"Edit",iup.menu({})},
                            {"Asset",iup.menu({})},
                            {"Component",iup.menu({})},
                            {"Tool",iup.menu({})},
                            {"Test",iup.menu({})}})
    local function exit()
        return iup.CLOSE
    end
    self.menu:add_item(iup.item({title="Exit",action=exit}),{"File"})
end


function editor_mainwindow:new_world(packages, systems)
    local world = scene.start_new_world(self.iq, self.config.fbw, self.config.fbh, packages, systems)
    task.loop(world.update)
end



local os = require "os"
local math = require "math"
function editor_mainwindow:run(config)
    print("bgfx.get_caps()")
    
    iup.SetGlobal("UTF8MODE", "YES")

    self.config = config
    local fb_width, fb_height = config.fbw, config.fbh

    self:build_window(fb_width, fb_height)

    

    self.canvas.map_cb = function()
        local nwh = iup.GetAttributeData(self.canvas,"HWND")
        rhwi.init {
            nwh = nwh,
            width = fb_width,
            height = fb_height,
        }
        self.asset_view:on_main_canvas_map()
    end
    iup.Map(self.canvas)
    
    self.dlg:showxy(iup.CENTER,iup.CENTER)
    self.dlg.usersize = nil
    iup.SetGlobal("GLOBALLAYOUTDLGKEY", "Yes");

   
    
    -- print_a(bgfx.get_caps())
    if (iup.MainLoopLevel()==0) then
        iup.MainLoop()
        iup.Close()
        bgfx.shutdown()
    end
end

return editor_mainwindow
