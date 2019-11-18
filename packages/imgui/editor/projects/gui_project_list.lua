local imgui             = require "imgui_wrap"
local widget            = imgui.widget
local flags             = imgui.flags
local windows           = imgui.windows
local util              = imgui.util
local cursor            = imgui.cursor
local enum              = imgui.enum
local IO                = imgui.IO

local pm                = require "antpm"
local gui_input         = require "gui_input"
local gui_mgr         = require "gui_mgr"
local gui_util          = require "editor.gui_util"
local fs                = require "filesystem"
local lfs                = require "filesystem.local"

local project_data_accessor    = require "editor.projects.project_data_accessor"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local GuiBase           = require "gui_base"
local GuiProjectList    = GuiBase.derive("GuiProjectList")
GuiProjectList.GuiName  = "GuiProjectList"
-- local SelectableHeight = cursor.GetTextLineHeight()+cursor.GetTextLineHeightWithSpacing()

function GuiProjectList:_init()
    GuiBase._init(self)
    self.win_flags = flags.Window { "MenuBar" }
    self.title_id = string.format("Project List###%s",self.GuiName)
    self.project_list = {} --[{name:xxx,path:xxx,},]
    self.project_details = {}
    self.select_index = 0
    self.cur_open_project = nil
    -- self.default_size = {800,700}
    self:_init_subcribe()
end

---event process
function GuiProjectList:_init_subcribe()
    hub.subscribe(Event.RequestAddPackageToProject,self.on_request_add_package_to_project,self)
end

function GuiProjectList:on_request_add_package_to_project(typ,path)
    log.info("on_request_add_package_to_project:",typ,path)
    self:add_package_to_cur_project(typ,path)
end
---

function GuiProjectList:on_update()
    local SelectableHeight = cursor.GetTextLineHeight()+cursor.GetTextLineHeightWithSpacing()

    if widget.BeginMenuBar() then
        if widget.MenuItem("New") then
            self:open_new_project_box()
        end
        if widget.MenuItem("Import") then
            self:open_import_project_box()
        end
        widget.EndMenuBar()
    end
    local project_list = self.project_list
    if #project_list == 0 then
        widget.Text("Not project exist.")
    end
    local w,_ = windows.GetContentRegionAvail()
    cursor.Columns(2,nil,false)
    cursor.SetColumnOffset(2,w-100)
    for i = #project_list,1,-1 do
        local p = project_list[i]
        local x,y = cursor.GetCursorPos()
        p.idstr = p.idstr or string.format("###%s",p.path)
        if widget.Selectable(p.idstr,self.select_index==i,0,SelectableHeight) then
            self.select_index = i
        end
        cursor.NextColumn()
        if self:is_project_opening(p) then
            cursor.SetNextItemWidth(-1)
            if widget.Button("Close") then
                self:close_project(true)
            end
            cursor.NextColumn()
            cursor.SetCursorPos(x,y)
            -- windows
            windows.PushStyleColor(enum.StyleCol.Text,0,1,0)
            widget.Text(string.format("Name:%s",p.name))
            widget.Text(string.format("Path:%s",p.path))
            windows.PopStyleColor(1)
        else
            if self.select_index == i then --selected
                cursor.SetNextItemWidth(-1)
                if widget.Button("Open") then
                    self:open_project(p)
                end
                cursor.SameLine()
                if widget.Button("Delete") then
                    self.select_index = nil
                    self:remove_project_by_index(i)
                end
            end
            cursor.NextColumn()
            cursor.SetCursorPos(x,y)
            widget.Text(string.format("Name:%s",p.name))
            widget.Text(string.format("Path:%s",p.path))
        end
    end
    cursor.Columns(1)
end

function GuiProjectList:is_project_opening(p)
    return self.cur_open_project and (self.cur_open_project.path == p.path)
end

function GuiProjectList:get_mainmenu()
    local path = {"Files"}
    return {
        {path,self._update_mainmenu}
    }
end

function GuiProjectList:_update_mainmenu()
    if widget.MenuItem("New Project") then
        self:open_new_project_box()
    end
    if widget.MenuItem("Import Project") then
        self:open_import_project_box()
    end
    if widget.MenuItem("Open Project") then
        self:open_project_list_box()
    end
    if widget.MenuItem("Save Project") then
        self:open_save_project_box()
    end
end

local function check_name_and_location(name_text,location_text)
    if #name_text == 0 then
        gui_util.notice({msg="project name is empty"})
        return false
    end
    if #location_text == 0 then
        gui_util.notice({msg="project location is empty"})
        return false
    end
    return true
end

local function create_project_at(name,location)
    local pm = require "antpm"
    local dir_obj = lfs.path(location)/name
    if lfs.exists(dir_obj) then
        gui_util.notice({msg="create project failed,same name exists"})
        return false
    end
    local current_path = lfs.current_path()
    local project_path = fs.path(pm.get_entry_pkg().."/project_temp")
    local local_path = project_path:localpath()
    lfs.copy(local_path,dir_obj)
    return tostring(dir_obj)
end

function GuiProjectList:open_new_project_box()
    local name_tbl = {
        text = "",
    }
    local location_tbl = {
        text = "./"
    }
    local result = 0
    local function cb()
        local name = tostring(name_tbl.text)
        local location = tostring(location_tbl.text)
        log("callback name:",name,"location:",location)
        if not check_name_and_location(tostring(name_tbl.text),tostring(location_tbl.text)) then
            return false
        end
        local success_path = create_project_at(name,location)
        if success_path then
            self:add_new_project(name,success_path)
        end
        return success_path
    end
    local function update_func()
        widget.Text("Name    ")
        cursor.SameLine()
        widget.InputText("##Name",name_tbl)
        widget.Text("Location")
        cursor.SameLine()
        widget.InputText("##Location",location_tbl)
        if widget.Button("Confirm") then
            if cb() then
                windows.CloseCurrentPopup()
            end
        end
        cursor.SameLine()
        if widget.Button("Cancel") then
            windows.CloseCurrentPopup()
        end
    end
    gui_util.popup(update_func,"New Project")
end

function GuiProjectList:add_new_project(name,path)
    table.insert(self.project_list,{name=name,path=path})
    self.dirty_flag = true
end

local function import_project_at(path,project_list)
    local path_obj = lfs.path(path)
    if lfs.exists(path_obj) then
        for i,p in ipairs(project_list) do
            if p.path == path then
                gui_util.notice({msg="project already imported"})
                return false
            end
        end
        local filename = path_obj:filename()
        return tostring(filename)
    else
        gui_util.notice({msg="project not exist"})
        return false
    end
end

function GuiProjectList:open_import_project_box()
    local path_tbl = {
        text = "./"
    }
    local function cb()
        local path = tostring(path_tbl.text)
        log("path:",path)
        if #path == 0 then
            gui_util.notice({msg="project path is empty"})
            return false
        end
        local name = import_project_at(path,self.project_list)
        if name then
            self:add_new_project(name,path)
        end
        return true
    end
    local function update_func()
        widget.Text("Path")
        cursor.SameLine()
        widget.InputText("##Path",path_tbl)
        if widget.Button("Confirm") then
            if cb() then
                windows.CloseCurrentPopup()
            end
        end
        cursor.SameLine()
        if widget.Button("Cancel") then
            windows.CloseCurrentPopup()
        end
    end
    gui_util.popup(update_func,"Import Project")
end

---project_access begin

function GuiProjectList:open_project(pdata)
    assert(self.cur_open_project_path ~= pdata.path)
    --todo close old project
    self:close_project(false)
    --read config
    local project_detail = project_data_accessor.load(pdata)
    self.project_details[pdata.path] = project_detail
    log.info_a(self.project_details[pdata.path])
    self.cur_open_project = pdata
    hub.publish(Event.OpenProject)
end

function GuiProjectList:close_project(publish_event)
    --todo close old project
    if self.cur_open_project then
        -- self.project_details[self.cur_open_project.path] = nil
        self.cur_open_project = nil
        if publish_event then
            hub.publish(Event.CloseProject)
        end
    end
end

--typ == "external",path relative to /Ant_dir
--typ == "inner",path relative to /Ant/xxx/your_project_dir
function GuiProjectList:add_package_to_cur_project(typ,path)
    assert(typ and path)
    local pdata,project_detail = self:get_cur_project()
    assert(pdata,"Not project opening.")
    local success = false
    if typ == "external" then
        success = project_data_accessor.add_external_package(pdata,project_detail,path)
    elseif typ == "inner" then
        success = project_data_accessor.add_inner_package(pdata,project_detail,path)
    else
        log.warning("Unknown type:"..typ)
    end
    if success then
        project_data_accessor.save(pdata,project_detail)
        log.info("Project saved successfully:",pdata.name)
        hub.publish(Event.ProjectModified)
    end
end

---project_access end


function GuiProjectList:remove_project_by_index(index)
    table.remove(self.project_list,index)
    self.dirty_flag = true
end

function GuiProjectList:open_project_list_box()
    self:on_open_click()
end

function GuiProjectList:open_save_project_box()
    log("To be implementd")
end

----------------custom_setting----------------

--override if needed
--return tbl
function GuiProjectList:save_setting_to_memory(clear_dirty_flag)
    if clear_dirty_flag then
        self.dirty_flag = false
    end
    log.info_a(self.project_list)
    return {
        project_list = self.project_list
    }
end

--override if needed
function GuiProjectList:load_setting_from_memory(seting_tbl)
    self.project_list = seting_tbl and seting_tbl.project_list or {}
    self.load_setting_from_memory = false
end

--override if needed
function GuiProjectList:is_setting_dirty()
    return self.dirty_flag
end

----------------custom_setting----------------

function GuiProjectList:get_cur_project()
    if self.cur_open_project then
        local path = self.cur_open_project.path
        local detail = self.project_details[path]
        return self.cur_open_project,detail
    end
end

function GuiProjectList:get_cur_project_name( )
    --todo
    return (self.cur_open_project and self.cur_open_project.name) or "Not Project"
end

return GuiProjectList