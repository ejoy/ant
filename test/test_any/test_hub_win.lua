--luacheck: globals iup import
require "iuplua"

local bgfx          = require "bgfx"

local editor        = import_package "ant.editor"
local inputmgr      = import_package "ant.inputmgr"
local iupcontrols   = import_package "ant.iupcontrols"
local rhwi          = import_package "ant.render".hardware_interface
local elog          = iupcontrols.logview
local tree          = iupcontrols.tree
local editor = import_package "ant.editor"
local hub = editor.hub
local editor_mainwindow = {}
editor_mainwindow.__index = editor_mainwindow

local nodes = {}

function editor_mainwindow:build_window(fbw, fbh)
    self.tree = tree.new({})
    self.canvas = iup.canvas {
        rastersize = fbw .. "x" .. fbh
    }
    
    self.dlg = iup.dialog {
        elog.window,
        title = "test_hub",
        -- shrink="YES",    -- logger box should be allow shrink
    }
    
end

function editor_mainwindow:init_event()
    local key_funcs = {}
    key_funcs[iup.K_1] = function()
        hub.subscibe("a channel",self.foo,self)
        hub.subscibe_mult("a channel",self.foo_all,self)
    end
    local count = 0
    key_funcs[iup.K_2] = function()
        count = count + 1
        hub.publish("a channel","hello world","~~~~",count) 
    end
    local time = 1
    key_funcs[iup.K_3] = function()
        time = time + 1
        hub.set_channel("a channel",{interval=time})
    end
    key_funcs[iup.K_4] = function()
        hub.unsubscibe("a channel",self.foo,self)
    end
    key_funcs[iup.K_5] = function()
        hub.unsubscibe_mult("a channel",self.foo_all,self)
    end
    key_funcs[iup.K_6] = function()
        hub.unsubscibe_all_by_target(self)
    end
    local k_any = function(dlg,c)
        if key_funcs[c] then
            key_funcs[c]()
        end
    end
    self.dlg.k_any = k_any

    print([[press c:random add 200 tree node
click mouse right button:del item
click mouse left button:print info]])
    local function fooo(a1,a2)
        print_a("foooo",a1,a2)
    end
    hub.subscibe("fs_hierarchy_select_file",fooo)
end

function editor_mainwindow:foo(a1,a2,a3)
    print("one",a1,a2,a3)
end
function editor_mainwindow:foo_all(msg_queue)
    print_a("mult",msg_queue)
end


local os = require "os"
local math = require "math"
function editor_mainwindow:run(config)
    iup.SetGlobal("UTF8MODE", "YES")

    self.config = config
    local fb_width, fb_height = config.fbw, config.fbh

    self:build_window(fb_width, fb_height)
    self:init_event()
    self.dlg:showxy(iup.CENTER,iup.CENTER)
    self.dlg.usersize = nil

    function self.canvas:map_cb()
        local nwh = iup.GetAttributeData(self.canvas,"HWND")
        rhwi.init {
            nwh = nwh,
            width = fb_width,
            height = fb_height,
        }
    end


    
    if (iup.MainLoopLevel()==0) then
        iup.MainLoop()
        iup.Close()
        bgfx.shutdown()
    end
end

return editor_mainwindow
