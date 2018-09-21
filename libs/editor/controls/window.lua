local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local elog = require "editor.log"
local hierarchyview = require "editor.controls.hierarchyview"
local propertycontrol = require "editor.controls.propertyview"
local eu = require "editor.util"
local rhwi = require "render.hardware_interface"
local bgfx = require "bgfx"
local scene = require "scene.util"

local propertyview = propertycontrol.new {
	tree = {
		ADDEXPANDED = "NO",
		HIDEBUTTONS = "NO",
		HIDELINES = "NO",
		IMAGELEAF = "IMGCOLLAPSED",
	},
	detail ={
		RASTERWIDTH2 = "150",
		FITTOTEXT = "C2"
	}
}

local editor_mainwindow = {}
editor_mainwindow.__index = editor_mainwindow

function editor_mainwindow:build_window(fbw, fbh)
    self.hierarchyview = hierarchyview
    self.propertyview = propertyview

    self.assetview = iup.list {
        expand = "YES",
    }

    self.canvas = iup.canvas {
        rastersize = fbw .. "x" .. fbh
    }
    
    local mainmenu = require "editor.controls.mainmenu"
    self.dlg = iup.dialog {
        iup.split {
            iup.split {
                iup.split {
                    iup.frame {
                        self.hierarchyview.window.view,
                        title = "hierarchy",
                    },
                    self.canvas,
                    showgrip = "NO",
                },
                elog.window,
                showgrip = "NO",
            },
            iup.split {
                iup.frame {
                    self.assetview,
                    title = "asset",
                    size = "HALFxHALF",
                },
                iup.frame {
                    self.propertyview.window,
                    title = "property",
                    size = "HALFxHALF",
                },
                expand = "YES",
                showgrip = "NO",
            },

            ORIENTATION="HORIZONTAL",
            expand = "YES",
            showgrip = "NO",
        },
        title = "Editor",
        shrink="YES",	-- logger box should be allow shrink
        menu = mainmenu,
    }
end


function editor_mainwindow:new_world(module_files)
	scene.start_new_world(self.iq, self.config.fbw, self.config.fbh, module_files)
end

function editor_mainwindow:run(config)
    iup.SetGlobal("UTF8MODE", "YES")

    self.config = config
    local fb_width, fb_height = config.fbw, config.fbh

    self:build_window(fb_width, fb_height)

    self.dlg:showxy(iup.CENTER,iup.CENTER)
	self.dlg.usersize = nil
	
	self.iq = inputmgr.queue(mapiup)
	eu.regitster_iup(self.iq, self.canvas)

    local nwh = iup.GetAttributeData(self.canvas,"HWND")
    rhwi.init(nwh, fb_width, fb_height)

    --self:new_world {"test_world.module", "engine.module", "editor.module"}
    -- to be able to run this script inside another context
    if (iup.MainLoopLevel()==0) then
        iup.MainLoop()
        iup.Close()

        bgfx.shutdown()
    end
end

return editor_mainwindow
