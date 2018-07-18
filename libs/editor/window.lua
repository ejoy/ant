
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local elog = require "editor.log"
local hierarchyview = require "editor.hierarchyview"
local propertycontrol = require "editor.propertyview"
local eu = require "editor.util"

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
    }
end

function editor_mainwindow:run(config)
    iup.SetGlobal("UTF8MODE", "YES")

    local fb_width, fb_height = config.fbw, config.fbh

    self:build_window(fb_width, fb_height)

    self.dlg:showxy(iup.CENTER,iup.CENTER)
	self.dlg.usersize = nil
	
	local iq = inputmgr.queue(mapiup)
	eu.regitster_iup(iq, self.canvas)

    local world = config.init_op(iup.GetAttributeData(self.canvas,"HWND"), 
        fb_width, fb_height, iq)
		
        
    -- to be able to run this script inside another context
    if (iup.MainLoopLevel()==0) then
        iup.MainLoop()
        iup.Close()

        config.shutdown_op()
    end
end

return editor_mainwindow