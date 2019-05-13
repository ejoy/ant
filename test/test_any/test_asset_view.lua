--luacheck: globals iup import
require "iuplua"


local bgfx          = require "bgfx"

local editor        = import_package "ant.editor"
local inputmgr      = import_package "ant.inputmgr"
local iupcontrols   = import_package "ant.iupcontrols"
local rhwi          = import_package "ant.render".hardware_interface
local camera_util          = import_package "ant.render".camera
local elog          = iupcontrols.logview
local tree = iupcontrols.tree
local fs_hierarchy = require "fs_hierarchy"
local asset_view = require "asset_view"
local task = editor.task
local scene = import_package "ant.scene"
local editor = import_package "ant.editor"
local mapiup = editor.mapiup
local fs = require "filesystem"
local iupcontrols = import_package "ant.iupcontrols"
local editor = import_package "ant.editor"
local hub = editor.hub
local asset_view_wnd = {}
asset_view_wnd.__index = asset_view_wnd

local packages = {
    "ant.testempty"
}


local systems = {
    "asset_view_render_sys",
    "camera_controller",
}


local nodes = {}
function asset_view_wnd:build_window(fbw, fbh)
    
    -- self.tree = tree.new({SHOWTOGGLE = "YES"})
    -- self.fs_hierarchy = fs_hierarchy.new()
    print(fbw, fbh)
    self.asset_view = asset_view.new()
    local canvas_w,canvas_h = math.floor(fbw),math.floor(fbh*0.7)
    self.canvas = iup.canvas( {rastersize=canvas_w.."x"..canvas_h} )
    function self.canvas.map_cb(canvas)
        if not self.world then
            local input_queue = inputmgr.queue()
            mapiup(input_queue, self.canvas)
            input_queue.world = "main_world"
            rhwi.init {
                nwh = iup.GetAttributeData(self.canvas,"HWND"),
                width = canvas_w,
                height = canvas_h,
            }
            -- self.world = scene.start_new_world(input_queue, canvas_w, canvas_h, packages, systems)
            -- local camera_eid = camera_util.create_main_render_camera(self.world)
            -- self.world:add_component(camera_eid,"camera_control",{})
            -- self.world:add_component(camera_eid,"show_light",true)
            -- self.world:add_component(camera_eid,"show_grid",true)
            -- local id = self.world:create_entity {
            --     position = {0, 0, 0, 1},
            --     rotation = {-90, -90, 0, 0},
            --     scale = {0.2, 0.2, 0.2, 0},
            --     can_render = true,
            --     mesh = {
            --         ref_path = {package = "ant.resources", filename = fs.path "PVPScene/campsite-door.mesh"}
            --     },
            --     material = {
            --         content = {
            --             {
            --                 ref_path = {package = "ant.resources", filename = fs.path "PVPScene/scene-mat.material"},
            --             }
            --         }
            --     },
            --     main_viewtag = true,
            -- }
            -- task.loop(scene.loop {
            --     update = {"timesystem", "message_system"}
            -- })
            -- self.world_update_func = self.world:update_func("update", {"timesystem", "message_system"})
        end
        self.maped = true
    end
    self.dlg = iup.dialog {
        iup.split{
            self.canvas,
            iup.split {
                elog.window,
                self.asset_view:get_view(),
                showgrip = "NO",
                ORIENTATION="VERTICAL"
            },
            showgrip = "NO",
            ORIENTATION="HORIZONTAL",
        },
        

        title = "Editor",
        -- shrink="YES",    -- logger box should be allow shrink
    }
    self.dlg.button_cb = function(_, btn, press, x, y, status)
        print("button_cb",btn, press, x, y, status)
    end


    -- test code
    local index = 2
    local list = {
        "PVPScene/campsite-door.mesh",
        "PVPScene/campsite-door.mesh",
        "PVPScene/campsite-door-01.mesh",
        "PVPScene/campsite-wall.mesh",
        "PVPScene/campsite-warmaterials-01.mesh",
        "PVPScene/tent-06.mesh",
        "PVPScene/woodbuilding-05.mesh",
        "PVPScene/woodother-34.mesh",
        "PVPScene/woodother-45.mesh",
        "PVPScene/woodother-46.mesh",
    }
    local len_list = #list
    local tex_index = 2
    local tex_list = {
        "PVPScene/siegeweapon_d.texture",
        "PVPScene/siegeweapon_n.texture",
        "PVPScene/tent_d.texture",
        "PVPScene/tent_n.texture",
    }  
    local len_tex_list = #tex_list
    self.dlg.k_any = function(_, code)
        print("k_any",code)
        if code == iup.K_1 then
            index = (index + 1)%len_list + 1
            index = 1
            local path = list[index]
            local mesh = {package = "ant.resources", filename = fs.path(path)}
            -- self.asset_view:set_model(mesh)
            hub.publish("fs_hierarchy_select_file",{mesh})
        elseif code == iup.K_2 then
            tex_index = (tex_index + 1)%len_tex_list + 1
            local res = {package="ant.resources",filename = fs.path(tex_list[tex_index])}
            -- self.asset_view:set_texture(res)
            hub.publish("fs_hierarchy_select_file",{res})
        elseif code == iup.K_3 then
            self.asset_view:show_camera()
        else
            self.asset_view:clear_cur_models()
        end
    end
    
end




local os = require "os"
local math = require "math"
function asset_view_wnd:run(config)
    iup.SetGlobal("UTF8MODE", "YES")

    self.config = config
    local fb_width, fb_height = config.fbw, config.fbh

    self:build_window(fb_width, fb_height)

    self.dlg:showxy(iup.CENTER,iup.CENTER)
    self.dlg.usersize = nil
    iup.SetGlobal("GLOBALLAYOUTDLGKEY", "Yes");
    -- local function mainloop()
    --     -- print("mainloop")
    --     self.asset_view:update()
    -- end

    -- task.loop(mainloop)

    if (iup.MainLoopLevel()==0) then
        iup.MainLoop()
        iup.Close()
        bgfx.shutdown()
    end
end

return asset_view_wnd
