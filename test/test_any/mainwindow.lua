--luacheck: globals iup import
require "iuplua"


local bgfx          = require "bgfx"

local editor        = import_package "ant.editor"
local inputmgr      = import_package "ant.inputmgr"
local iupcontrols   = import_package "ant.iupcontrols"
local rhwi          = import_package "ant.render".hardware_interface
local elog          = iupcontrols.logview
local tree = iupcontrols.tree

local editor_mainwindow = {}
editor_mainwindow.__index = editor_mainwindow

local nodes = {}
function editor_mainwindow:build_window(fbw, fbh)
    self.tree = tree.new({})
    self.canvas = iup.canvas {
        rastersize = fbw .. "x" .. fbh
    }
    
    self.dlg = iup.dialog {
        iup.split {
                self.tree.view,
                elog.window,
                -- showgrip = "NO",
                ORIENTATION="HORIZONTAL"
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
    iup.SetGlobal("UTF8MODE", "YES")

    self.config = config
    local fb_width, fb_height = config.fbw, config.fbh

    self:build_window(fb_width, fb_height)

    self.dlg:showxy(iup.CENTER,iup.CENTER)
    self.dlg.usersize = nil
    local last = nil
    local count = 1
    local k_any = function(dlg,c)
        if c == iup.K_c then
            local time = os.clock()
            local last_last = last
            last = self.tree:add_child(last_last,"test_add")
            for i = count,count+100 do
                if tonumber(self.tree.view.COUNT) > 0 then
                    local rid = math.random(self.tree.view.COUNT)
                    local parent = self.tree:findchild_byid(rid-1)
                    self.tree:add_child(parent,"test_add"..i)
                else
                    self.tree:add_child(nil,"test_add"..i)
                end

            end
            count = count+201
            for i = count,count+100 do
                local rid = math.random(self.tree.view.COUNT)
                local parent = self.tree:findchild_byid(rid-1)
                self.tree:insert_sibling(parent,"test_sibl"..i)
            end
            count = count+201

            local add_time = os.clock()-time
            time = os.clock()
            -- for i = 1,100 do
            --     print(">>")
            --     print(count-100, (self.tree:findchild_byid(count-100)).name)
            -- end
            print(
                string.format(
                "add_child 200 times durction:%0.3f\tfind_child_by_id 100 times durction:%0.3f",
                add_time,
                os.clock()-time)
            )
            for id = 0,self.tree.view.COUNT-1 do
                assert(self.tree.view["TITLE"..id] == self.tree:findchild_byid(id).name)
            end
        end

    end
    self.dlg.k_any = k_any

    self.tree.view.rightclick_cb =  function (view,id)
        -- local last_count = self.tree.view.count
        -- self.tree:del_id(id)
        -- print(
        --     string.format(
        --         "del id:%d\tbefore count:last_count:%d\tcurrent count:%d"
        --         ,id,last_count,self.tree.view.count
        --     )
        -- )
    end
    self.tree.view.selection_cb = function(view,id)
        print(id,(self.tree:findchild_byid(id)).name)
    end
    print("press c:random add 200 tree node")
    print("click mouse right button:del item")
    print("click mouse left button:print info")
    a = self.tree:add_child(nil,"sada")
    self.tree:add_child(a,"sa3da")

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
