local log = log and log(...) or print
local scene_control = {}; scene_control.__index = scene_control
local FILE_MEMU = {"File"}
local iupcontrols   = import_package "ant.iupcontrols"
local hub          = iupcontrols.common.hub


function scene_control:init_submenu()
    self.open_scene_item = iup.item({title="Open Scene"})
    function self.open_scene_item.action()
        self:open_scene_click()
    end
    self.new_scene_item = iup.item({title="New Scene"})
    function self.new_scene_item.action()
        self:new_scene_click()
    end
    self.close_scene_item = iup.item({title="Close Scene"})
    function self.close_scene_item.action()
        self:new_scene_click()
    end
    self.menubar:add_items({self.open_scene_item,
                        self.new_scene_item,
                        self.close_scene_item,
                        iup.separator({})},
                        FILE_MEMU,
                        0)

end

function scene_control:init_hub()
    --listen hub for scene open event
    local fs_hierarchy_hub = require "fs_hierarchy_hub"
    hub.subscibe(fs_hierarchy_hub.CH_OPEN_FILE,
                self.open_scene_file,
                self)
end

function scene_control:open_scene_file(ref_file)
    print_a("open_scene_file:",ref_file)

end

function scene_control:open_scene_click()
    local localfs = require "filesystem.local"
    local filedlg = iup.filedlg
    {
        dialogtype = "OPEN",
        filter = filepattern,
        filterinfo = "Map File",
        parentdialog = parentdlg,
    }

    local seletfileop = function()
        
        print_a("seletfileop",localfs.path(filedlg.value))
    end
    
    filedlg:popup(iup.CENTERPARENT, iup.CENTERPARENT)
    if tonumber(filedlg.status) ~= -1 then
        seletfileop(localfs.path(filedlg.value))
    end
    filedlg:destroy()
end

function scene_control:new_scene_click()
    --todo
    print("todo:new_scene")
end

function scene_control:close_scene_click()
    --todo
    print("todo:close_scene")
end




function scene_control.new(menubar)
    local ins = {}
    ins.menubar = menubar
    ins = setmetatable(ins, scene_control)
    ins:init_submenu()
    ins:init_hub() 
    return ins
end


return scene_control