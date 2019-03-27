--luacheck: globals iup import
require "iuplua"


local bgfx          = require "bgfx"

local editor        = import_package "ant.editor"
local inputmgr      = import_package "ant.inputmgr"
local iupcontrols   = import_package "ant.iupcontrols"
local rhwi          = import_package "ant.render".hardware_interface
local elog          = iupcontrols.logview
local tree = iupcontrols.tree
local fs_hierarchy = require "fs_hierarchy"

local editor_mainwindow = {}
editor_mainwindow.__index = editor_mainwindow



local nodes = {}
function editor_mainwindow:build_window(fbw, fbh)
    
    -- self.tree = tree.new({SHOWTOGGLE = "YES"})
    self.fs_hierarchy = fs_hierarchy.new()
    self.canvas = iup.canvas {
        rastersize = fbw*0.8 .. "x" .. fbh*0.8
    }
    
    self.dlg = iup.dialog {
        iup.split{
            iup.split {
                iup.split {
                    self.fs_hierarchy:get_view(),
                    self.canvas,
                    showgrip = "NO",
                },
                iup.split{
                    elog.window,
                    iup.fill {},
                    showgrip = "NO",
                };
                showgrip = "NO",
                ORIENTATION="HORIZONTAL"
            },
        },
        
        title = "Editor",
        -- shrink="YES",    -- logger box should be allow shrink
    }
    
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

    self.dlg:showxy(iup.CENTER,iup.CENTER)
    self.dlg.usersize = nil
    iup.SetGlobal("GLOBALLAYOUTDLGKEY", "Yes");
  
    local nwh = iup.GetAttributeData(self.canvas,"HWND")
    rhwi.init {
        nwh = nwh,
        width = fb_width,
        height = fb_height,
    }
    -- print_a(bgfx.get_caps())
    if (iup.MainLoopLevel()==0) then
        iup.MainLoop()
        iup.Close()
        bgfx.shutdown()
    end
end

return editor_mainwindow
