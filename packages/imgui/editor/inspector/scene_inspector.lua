local imgui             = require "imgui_wrap"
local widget            = imgui.widget
local flags             = imgui.flags
local windows           = imgui.windows
local util              = imgui.util
local cursor            = imgui.cursor
local enum              = imgui.enum
local IO                = imgui.IO
local gui_util          = require "editor.gui_util"
local fs                = require "filesystem"
local localfs           = require "filesystem.local"
local assetmgr          = import_package "ant.asset".mgr

local scene_data_accessor = require "editor.scene.scene_data_accessor"
local SceneMeta         = scene_data_accessor.SceneMeta

local InspectorBase     = require "editor.inspector.inspector_base"
local SceneInspector    = InspectorBase.derive("SceneInspector")

function SceneInspector:_init()
    InspectorBase._init(self)
    self.res_ext = "scene"
    self.scene_info = nil
end

--todo
function SceneInspector:before_res_open()
    --glb
    local scene_pkg_path = self.res_pkg_path
    -- local local_path = gui_util.pkg_path_to_local(glb_path)
    local scene_data = fs.dofile(scene_pkg_path)
    log.info_a(scene_data)
    self.scene_info = scene_data
    self.scene_str = dump_a({scene_data},"\t")
end

--todo
function SceneInspector:clean_modify()
    local local_path = gui_util.pkg_path_to_local(self.res_pkg_path)
    local scene_data = fs.dofile(scene_pkg_path)
    self.scene_info = scene_data
    self.scene_str = dump_a({scene_data},"\t")
    self:clear_ui_cache()
    self.modified = false
end

--todo
function SceneInspector:on_apply_modify()

    -- local tbl = {}
    -- table.insert(tbl,"return {\n")
    -- self:write_cfg(self.scene_info,SceneMeta,tbl,"\t")
    -- table.insert(tbl,"}\n")
    -- local str = table.concat(tbl)
    -- log(str)
    -- local local_path = gui_util.pkg_path_to_local(self.res_pkg_path)
    -- local f = io.open(local_path,"w")
    -- f:write(str)
    -- f:close()
    scene_data_accessor.save_scene_file(self.res_pkg_path,self.scene_info)
    self.modified = false
end

function SceneInspector:on_update()
    self:BeginProperty()
    widget.Text(self.res_pkg_path:string())
    -- self:update_lk_info()
    self:update_scene_ui()
    if self.scene_info then
        if widget.CollapsingHeader("Scene Info") then
            if not self.glb_info_cache then
                self.glb_info_cache = {
                    text = self.scene_str,
                    flags = flags.InputText{ "Multiline","ReadOnly"},
                    width = -1,
                    -- height = -1,
                }
            end
            widget.InputText("##detail",self.glb_info_cache)
        end
    end
    if self.modified then
        if widget.Button("Revert") then
            self:clean_modify()
        end
        cursor.SameLine()
        if widget.Button("Apply") then
            self:on_apply_modify()
        end
    end
    self:EndProperty()
end

function SceneInspector:update_scene_ui()
    self.modified = self:show_import_cfg(self.scene_info,SceneMeta) or self.modified
end


return SceneInspector