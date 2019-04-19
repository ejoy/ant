local log = log and log(...) or print
local scene_control = {}; scene_control.__index = scene_control
local FILE_MEMU = {"File"}
local iupcontrols   = import_package "ant.iupcontrols"
local hub           = iupcontrols.common.hub
local editor        = import_package "ant.editor"
local mapiup        = editor.mapiup
local task          = editor.task
local vfs           = require "vfs"
local inputmgr      = import_package "ant.inputmgr"


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

local function load_package(path)
    local localfs = require "filesystem.local"
    assert(path:is_absolute(path))

    local mapcfg = localfs.dofile(path) 
    return mapcfg.name, mapcfg.systems
end
local pkg_name
function scene_control:openMap(path)
    -- guiOpenMap.active = "OFF"

    local pkgname, pkgsystems = load_package(path)

    if pkgname == assert(_PACKAGENAME) then
        iup.Message("Error", "Could not open entry package, or open a package with the same name as entry package")
    end

    local packages = {
        -- "ant.EditorLauncher",
        -- "ant.objcontroller",
        "ant.hierarchy.offline",
    }
    local systems = {
        --"pickup_material_system",
        --"pickup_system",
        "obj_transform_system",
        "build_hierarchy_system",
        -- "editor_system"
    }

    vfs.remove_mount("currentmap")
    vfs.add_mount("currentmap", path:parent_path())
    local pm = require "antpm"
    if not pm.find(pkg_name) then
        pkg_name = pm.register("currentmap")
    end
    
    packages[#packages+1] = pkgname
    table.move(pkgsystems, 1, #pkgsystems, #systems+1, systems)
    self:new_world(packages, systems)
end
function scene_control:new_world(packages, systems)
    local scene         = import_package "ant.scene".util
    if self.world then
        self.world.need_stop = true
    end
    self.config = {
        fbw=1024, fbh=768,
    }

    self.world = scene.start_new_world(self.input_queue, self.config.fbw, self.config.fbh, packages, systems)        
    task.loop(scene.loop(self.world, {
        update = {"timesystem", "message_system"}
    }))
    self.world.stop = function()
        task.exit()
    end
end

function scene_control:open_scene_click()
    local localfs = require "filesystem.local"
    local filedlg = iup.filedlg
    {
        dialogtype = "OPEN",
        filter = "package.lua",
        filterinfo = "Map File",
        parentdialog = iup.GetDialog(self.menubar:get_view()),
    }

    local seletfileop = function()
        print_a("seletfileop",filedlg.value,localfs.path(filedlg.value))
        self:openMap(localfs.path(filedlg.value))
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




function scene_control.new(menubar,input_queue)
    local ins = {}
    ins.menubar = menubar
    ins.input_queue = input_queue
    ins = setmetatable(ins, scene_control)
    ins:init_submenu()
    ins:init_hub() 
    return ins
end


return scene_control