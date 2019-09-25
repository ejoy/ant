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

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local GuiBase           = require "gui_base"
local GuiProjectView    = GuiBase.derive("GuiProjectView")
GuiProjectView.GuiName  = "GuiProjectView"

function GuiProjectView:_init()
    GuiBase._init(self)
    self.win_flags = flags.Window { "MenuBar" }
    self.title_id = string.format("Project###%s",self.GuiName)
    self.default_size = {800,700}
    self.left_precent = 0.3
    self:_init_subcribe()
    self.cur_pkg_name = nil
    self.pkg_list = nil
    self.selection = {list={},map={}} --pathstr
    self.focus_path_obj = nil
    self.is_directory_cache = {}
end

function GuiProjectView:_init_subcribe()

end

function GuiProjectView:on_update(delta)
    local winw,h = windows.GetContentRegionAvail()
    local menu_height = self:_update_menu_bar()
    local fh = cursor.GetFrameHeightWithSpacing()
    h = h - fh - menu_height
    local left_w = math.floor(winw * self.left_precent+0.5)
    cursor.Columns(2)
    cursor.Separator()
    -- if windows.BeginChild("left_part",left_w,h,false,0) then
    if windows.BeginChild("left_part",0,0,false,0) then
        self:on_dir_update()
    end
    windows.EndChild()
    cursor.NextColumn()
    -- windows.PushStyleVar(enum.StyleVar.ItemSpacing,0,0)
    -- widget.InvisibleButton("vsplitter",5,h)
    -- if util.IsItemActive() then
    --     cursor.SetMouseCursor(enum.MouseCursor.ResizeEW)
    --     local new_left_w = left_w + gui_input.get_mouse_delta().x
    --     self.left_precent = new_left_w/winw
    --     self.left_precent = math.min(0.9,self.left_precent)
    --     self.left_precent = math.max(0.1,self.left_precent)
    -- end
    -- if util.IsItemHovered() then
    --     cursor.SetMouseCursor(enum.MouseCursor.ResizeEW)
    -- end
    -- cursor.SameLine()
    -- windows.PopStyleVar()
    -- if windows.BeginChild("right_part",winw-left_w-7,h,false,0) then
    if windows.BeginChild("right_part",0,0,false,0) then

        self:on_file_update()
    end
    windows.EndChild()
    cursor.Columns(1)

end

function GuiProjectView:_update_menu_bar()
    local _,y1 = cursor.GetCursorPos()
    if widget.BeginMenuBar() then
        widget.Button("button")
        widget.EndMenuBar()
    end
    local _,y2 = cursor.GetCursorPos()
    return y2-y1
end

local function get_parent_list(path_obj)
    local list = {}
    while ( path_obj:string() ~= "" ) do
        table.insert(list,path_obj)
        path_obj = path_obj:parent_path()
    end
    return list
end

function GuiProjectView:list_directory(path_obj)
    local now = os.clock()
    if path_obj == self.last_call_list_directory_arg then
        if now - self.last_call_list_directory_t < 3 then
            return self.last_call_list_directory_result
        end
    end
    self.is_directory_cache = {}
    self.last_call_list_directory_t = now
    self.last_call_list_directory_arg = path_obj
    local childs =  path_obj:list_directory()
    local result = {}
    for child_obj in childs do
        table.insert(result,child_obj)
    end
    local function cmp_path_obj(a,b)
        return string.lower(a:string())<string.lower(b:string())
    end 
    table.sort(result,cmp_path_obj)
    self.last_call_list_directory_result = result
    return result
end

function GuiProjectView:is_directory(path_obj)
    if self.is_directory_cache[path_obj] ~= nil then
        return self.is_directory_cache[path_obj]
    else
        local d = fs.is_directory(path_obj)
        self.is_directory_cache[path_obj] = d
        return d
    end
end


function GuiProjectView:on_dir_update(delta)
    -- if self.pkg_list = 
    self:on_pkglist_update()
    if not self.cur_pkg_name then
        widget.Text("Not package selected.")
        return 
    end

    local root_dir = fs.path("/pkg/"..self.cur_pkg_name)
    if not fs.exists(root_dir) then
        widget.Text("Package not exists.")
    end
    ---
    local cur_dir = root_dir
    --do
    if self:push_open_tree_node(root_dir,true,false) then

        local count = 1
        local is_break = false
        if self.focus_path_obj then
            local foucs_path_tbl = get_parent_list(self.focus_path_obj)
            for i = #foucs_path_tbl-2,1,-1 do
                local open = self:push_open_tree_node(foucs_path_tbl[i],true,false)
                if open then
                    count = count + 1
                else
                    is_break = true
                    break
                end
            end
            cur_dir = foucs_path_tbl[1]
        else
            self.focus_path_obj =  cur_dir
        end

        if not is_break then
            local childs =  self:list_directory(self.focus_path_obj)

            for _,child_obj in ipairs(childs) do
                if self:is_directory(child_obj)then
                    if self:push_open_tree_node(child_obj,true,true) then
                        self:push_tree_end()
                    end
                end
            end
        end
        for i = 1,count do
            self:push_tree_end()
        end
    end
end

function GuiProjectView:on_path_click(path_obj)
    local path_str = path_obj:string()
    local ctrl = gui_input.get_ctrl_state(gui_input.KeyCtrl)
    if ctrl then
        --mult select
        table.insert(self.selection.list,path_str)
        self.selection.map[path_str] = true
    else
        --single select
        self.selection.list = {path_str}
        local map = self.selection.map
        for k,_ in pairs(map) do
            map[k] = false
        end
        map[path_str] = true
    end
end

function GuiProjectView:on_path_double_click(path_obj,is_dir)
    if is_dir then
        self.focus_path_obj = path_obj
        log.info_a("focus_path_obj",self.focus_path_obj)
    else
        log.trace("Double click file",path_obj:string())
        hub.publish(Event.InspectRes,path_obj:string())
        
    end
end

--return double clicked
function GuiProjectView:push_open_tree_node(path_obj,is_dir,is_leaf)
    local my_path = path_obj:string()
    local my_name = (path_obj:filename()):string()
    local selected = self.selection.map[my_path]
    local flags_tbl = {}
    if seelcted then table.insert(flags_tbl,"Selected") end
    if is_leaf then table.insert(flags_tbl,"Leaf") end
    local my_flag = flags.TreeNode(flags_tbl)
    widget.SetNextItemOpen(true)
    local open = widget.TreeNode(my_name,my_flag)
    local is_click = util.IsItemClicked()
    local is_dclick = is_click and util.IsMouseDoubleClicked(0)
    if is_dclick then
        self:on_path_double_click(path_obj,is_dir)
    elseif is_click then
        self:on_path_click(path_obj)
    end

    return open
end

function GuiProjectView:push_tree_end()
    widget.TreePop()
end

function GuiProjectView:on_pkglist_update()
    --check pkg list every minute
    self.pkg_update_t = (self.pkg_update_t or 0)+1
    if (not self.pkg_list) or (self.pkg_update_t > 60) then
        self.pkg_update_t = 0
        local list = pm.get_pkg_list()
        table.sort(list)
        self.pkg_list = list
    end
    if not self.pkg_ui_tbl then
        self.pkg_ui_tbl = {self.pkg_list[1]}
        self.cur_pkg_name = self.pkg_ui_tbl[1]
    end
    local change = false
    local w,h = windows.GetContentRegionAvail()
    cursor.SetNextItemWidth(w)
    if widget.BeginCombo("###PKG_LIST",self.pkg_ui_tbl) then
        for i,pname in ipairs(self.pkg_list) do
            if widget.Selectable(pname,self.pkg_ui_tbl) then
                change = true
            end
        end
        widget.EndCombo()
        if change then
            self.cur_pkg_name = self.pkg_ui_tbl[1]
            self.focus_path_obj = nil
            log.trace("cur_pkg",self.cur_pkg_name)
        end
    end
    cursor.Separator()
    return change
end

function GuiProjectView:on_file_update(delta)

    if self.focus_path_obj then
        local childs =  self:list_directory(self.focus_path_obj)
        local map = self.selection.map
        for _,child_obj in ipairs(childs) do
            if (not self:is_directory(child_obj)) and(not child_obj:equal_extension(".lk")) then
                local name = (child_obj:filename()):string()
                local click,double_click = nil
                if widget.Selectable(name,map[child_obj:string()]) then
                end
                if util.IsItemClicked() then
                    if util.IsMouseDoubleClicked(0) then
                        double_click = true
                    else
                        click = true
                    end
                end
                if click then
                    self:on_path_click(child_obj,false)
                elseif double_click then
                    self:on_path_double_click(child_obj,false)
                end
            end
        end
    end

end


return GuiProjectView