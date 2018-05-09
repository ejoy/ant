
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local elog = require "editor.log"

local editor_mainwindow = {}
editor_mainwindow.__index = editor_mainwindow

function editor_mainwindow.run(config)
    iup.SetGlobal("UTF8MODE", "YES")

    local fb_width, fb_height = config.fbw, config.fbh

    local canvas = iup.canvas {
        rastersize = fb_width .. "x" .. fb_height
    }

    local dlg = iup.dialog {
        iup.split {
            canvas,
            elog.window,
            SHOWGRIP = "NO",
        },
        title = "simple",
        shrink="yes",	-- logger box should be allow shrink
    }

    dlg:showxy(iup.CENTER,iup.CENTER)
    dlg.usersize = nil

    local init = config.init_op

    init(iup.GetAttributeData(canvas,"HWND"), 
        fb_width, fb_height,
        inputmgr.queue(mapiup, canvas))

    -- to be able to run this script inside another context
    if (iup.MainLoopLevel()==0) then
        iup.MainLoop()
        iup.Close()

        local shutdown = config.shutdown_op
        shutdown()
    end
end

return editor_mainwindow