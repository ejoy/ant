--luacheck: globals iup import
require "iuplua"


local bgfx 			= require "bgfx"

local editor 		= import_package "ant.editor"
local inputmgr 		= import_package "ant.inputmgr"
local iupcontrols 	= import_package "ant.iupcontrols"
local rhwi 			= import_package "ant.render".hardware_interface
local scene 		= import_package "ant.scene".util
local elog 			= iupcontrols.logview
local hierarchyview = iupcontrols.hierarchyview
local propertycontrol = iupcontrols.propertyview
local mapiup 		= editor.mapiup
local task 			= editor.task

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

    self.canvas = iup.canvas {
        rastersize = fbw .. "x" .. fbh
    }
	
	local mainmenu = require "mainmenu"
    
    self.dlg = iup.dialog {
        iup.split {
            iup.split {
                iup.split {
                    iup.frame {
                        self.hierarchyview.view,
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
                    self.propertyview.view,
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


function editor_mainwindow:new_world(packages, systems)
	self.world = scene.start_new_world(self.iq, self.config.fbw, self.config.fbh, packages, systems)		
	task.loop(scene.loop(self.world, {
		update = {"timesystem", "message_system"}
	}), function (co, status)
		iup.Message("Error", string.format("Error:%s\n%s", status, debug.traceback(co)))
	end)
    self.world.stop = function()
        task.exit()
    end
end

function editor_mainwindow:run(config)
    iup.SetGlobal("UTF8MODE", "YES")

    self.config = config
    local fb_width, fb_height = config.fbw, config.fbh

    self:build_window(fb_width, fb_height)

    self.dlg:showxy(iup.CENTER,iup.CENTER)
	self.dlg.usersize = nil

	self.iq = inputmgr.queue()
	mapiup(self.iq, self.canvas)

	local nwh = iup.GetAttributeData(self.canvas,"HWND")
    rhwi.init {
		nwh = nwh,
		width = fb_width,
		height = fb_height,
	}

    if (iup.MainLoopLevel()==0) then
        iup.MainLoop()
        iup.Close()

        bgfx.shutdown()
    end
end

return editor_mainwindow
