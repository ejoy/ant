
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local elog = require "editor.log"
local hierarchyview = require "editor.hierarchyview"

local editor_mainwindow = {}
editor_mainwindow.__index = editor_mainwindow

editor_mainwindow.hierarchyview = hierarchyview

editor_mainwindow.assetview = iup.list {
    expand = "YES",
}

editor_mainwindow.propertyview = iup.tree {
    hidebuttons="NO",
    expand = "YES",
    title = "components",
}

function editor_mainwindow:run(config)
    iup.SetGlobal("UTF8MODE", "YES")

    local fb_width, fb_height = config.fbw, config.fbh

    local canvas = iup.canvas {
        rastersize = fb_width .. "x" .. fb_height
    }

    self.dlg = iup.dialog {
        iup.split {
            iup.split {
                iup.split {
                    iup.frame {
                        hierarchyview.window,
                        title = "hierarchy",
                    },
                    canvas,                
                    showgrip = "NO",
                },
                elog.window,
                showgrip = "NO",
            },
            iup.split {
                iup.frame {
                    assetview,
                    title = "asset",
                    size = "HALFxHALF",
                },                
                iup.frame {
                    propertyview,
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

    dlg:showxy(iup.CENTER,iup.CENTER)
    dlg.usersize = nil

    local world = config.init_op(iup.GetAttributeData(canvas,"HWND"), 
        fb_width, fb_height,
        inputmgr.queue(mapiup, canvas))
        
    -- to be able to run this script inside another context
    if (iup.MainLoopLevel()==0) then
        iup.MainLoop()
        iup.Close()

        config.shutdown_op()
    end
end

return editor_mainwindow