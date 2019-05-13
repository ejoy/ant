--luacheck: globals iup import
require "iuplua"
iup.SetGlobal("GLOBALLAYOUTDLGKEY", "Yes");

local bgfx          = require "bgfx"

local editor        = import_package "ant.editor"
local inputmgr      = import_package "ant.inputmgr"
local iupcontrols   = import_package "ant.iupcontrols"
local rhwi          = import_package "ant.render".hardware_interface
local elog          = iupcontrols.logview
local tree          = iupcontrols.tree
local editor = import_package "ant.editor"
local hub = editor.hub
local MenuBar          = iupcontrols.menubar

local editor_mainwindow = {}
editor_mainwindow.__index = editor_mainwindow

local nodes = {}

function editor_mainwindow:build_window(fbw, fbh)
    self.tree = tree.new({})
    self.canvas = iup.canvas {
        rastersize = fbw .. "x" .. fbh
    }
    self.menu = MenuBar.new()
    self.menu:add_items({iup.item {title="dnil"}},{"Aaaaa","Bbbbb"})
    self.menu:add_items({iup.item {title="d1"}},{"Aaaaa","Bbbbb"},1)
    self.menu:add_items({iup.item {title="d3"}},{"Aaaaa","Bbbbb"},3)
    self.menu:add_items({iup.item {title="d2"}},{"Aaaaa","Bbbbb"},2)
    local test = function()
        print("test")
        self:foo(24234,234,2,423,4)
    end
    local test_btn = iup.item({title="asd",action=test})
    self.menu:add_items({test_btn},{"Aaaaa","Bbbbb"},2)
    self.dlg = iup.dialog {
        elog.window,
        menu = self.menu:get_view(),
        title = "test_hub",
        -- shrink="YES",    -- logger box should be allow shrink
    }
    
end

function editor_mainwindow:init_event()
    local key_funcs = {}
    local add_menu = nil
    key_funcs[iup.K_1] = function()
        add_menu = iup.submenu({
            iup.menu({
                iup.item({title="haha"})
            });
            title="sub1"
        })
        local sep = iup.separator({})
        local item = iup.item({title="item1"})
        self.menu:add_items({add_menu,sep,item},{"Aaaaa","Bbbbb"})

    end
    local count = 0
    key_funcs[iup.K_2] = function()
        self.menu:remove_item(add_menu)
    end
    local time = 1
    key_funcs[iup.K_3] = function()
        print(self.menu:get_item({"Aaaaa","Bbbbb","sub1"}))
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
