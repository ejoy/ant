local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local IO      = imgui.IO

local GuiBase = require "gui_base"
local gui_input = require "gui_input"
local gui_util = require "editor.gui_util"
local SettingDefine = require "editor.component_setting_define"

local ComponentSetting = require "editor.component_setting"

local GuiComponentStyle = GuiBase.derive("GuiComponentStyle")

local ComSchemaType = {
    Com = 1,
    Prim = 2,
    Map = 3,
    Array = 4,
    Alias = 5,
}

GuiComponentStyle.GuiName = "GuiComponentStyle"

local DefaultPath = "editor.com_sytle.default.cfg"

function GuiComponentStyle:_init()
   GuiBase._init(self)
   self.default_size = {800,700}
   self._is_opened = false
   self.left_precent = 0.3
   self.title_id = "ComponentStyleEditor"
   self.schema_map = self:get_schema_map()
end

function GuiComponentStyle:on_update()
    local winw,h = windows.GetContentRegionAvail()
    local menu_height = self:_update_menu_bar()
    local fh = cursor.GetFrameHeightWithSpacing()
    h = h - fh - menu_height
    local left_w = math.floor(winw * self.left_precent+0.5)
   
    if windows.BeginChild("left_part",left_w,h,true,0) then
        self:_render_component_tree()
    end
    windows.EndChild()
    windows.PushStyleVar(enum.StyleVar.ItemSpacing,0,0)
    cursor.SameLine()
    widget.InvisibleButton("vsplitter",5,h)
    if util.IsItemActive() then
        local new_left_w = left_w + gui_input.get_mouse_delta().x
        self.left_precent = new_left_w/winw
        self.left_precent = math.min(0.9,self.left_precent)
        self.left_precent = math.max(0.1,self.left_precent)
    end

    cursor.SameLine()
    windows.PopStyleVar()
    if windows.BeginChild("right_part",winw-left_w-7,h,true,0) then
        self:_render_style_part()
        -- widget.Text("todo:render_style")
    end
    windows.EndChild()
    
    if widget.Button("Save Setting") then
        local data = self.com_setting:get_save_data()
        local thread = require "thread"
        local packed_data = thread.pack(data)
        -- local after = thread.unpack(packed_data)
        -- print_a("after:",data)
        local f = gui_util.open_current_pkg_path(DefaultPath,"wb")
        f:write(packed_data)
        f:close()
        local msg = string.format("Save Successfully!\nPath:%s",DefaultPath)
        gui_util.notice({msg=msg})
    end
    cursor.SameLine()
    if widget.Button("Reset Setting") then
        self:_init_schema_cfg()
        local msg = string.format("Reset Successfully!\nPath:%s",DefaultPath)
        gui_util.notice({msg=msg})
    end
    -- cursor.SameLine()

    -- if widget.Button("Reset Setting") then
    --     print(dump_a({self.com_setting},"   "))
    -- end

end

function GuiComponentStyle:_update_menu_bar()
    local _,y1 = cursor.GetCursorPos()
    if widget.BeginMenuBar() then
        if widget.MenuItem("test") then
            print("get_schema_map")
            print_a(self:get_schema_map())
        end
        widget.EndMenuBar()
    end
    local _,y2 = cursor.GetCursorPos()
    return y2-y1
end

function GuiComponentStyle:get_schema_map()
    local util = require "editor.gui_util"
    local schema_map = util.get_all_schema()
    return schema_map
end
------------------render setting----------------------------
function GuiComponentStyle:_render_style_part()
    if self.selected then
        self:_render_style_setting()
        if widget.CollapsingHeader("Path Detail") then
            widget.Text(dump_a({self.selected.path_tbl},"  "))
        end
        if widget.CollapsingHeader("Schema Detail") then
            widget.Text(dump_a({self.selected.schema},"  "))
        end
    end
end

function GuiComponentStyle:_render_style_setting()
    local selected = self.selected
    local field_list = ComponentSetting.CfgList["Normal"]
    if selected.type == ComSchemaType.Com then
        field_list = ComponentSetting.CfgList["Com"]
    elseif selected.type == ComSchemaType.Array then
        field_list = ComponentSetting.CfgList["Array"]
    elseif selected.type == ComSchemaType.Map then
        field_list = ComponentSetting.CfgList["Map"]
    end
    -- print_a(field_list)
    local path_tbl = selected.path_tbl
    local result = {}
    for i,field in ipairs(field_list) do
        local value,source_path_tbl =  self.com_setting:getv(selected.path_tbl,field)
        result[field] = {value,source_path_tbl,(source_path_tbl==path_tbl)}
        -- self:_render_single_setting(selected.path_tbl,field)
    end
    --custom
    widget.SetNextItemOpen(true,"FirstUseEver")
    if widget.CollapsingHeader("ComponentSettings") then
        for i,field in ipairs(field_list) do
            local v = result[field]
            if v[3] then
                self:_render_a_custom_setting(v[2],field,v[1])
            end
        end
        -- inherit
        widget.SetNextItemOpen(true,"FirstUseEver")
        if widget.CollapsingHeader("[Inherited]") then
            for i,field in ipairs(field_list) do
                local v = result[field]
                if not v[3] then
                    self:_render_a_inherited_setting(v[2],path_tbl,field,v[1])
                end
            end
        end
    end
end

function GuiComponentStyle:_render_a_custom_setting(path_tbl,field,value)
    local setting_define = SettingDefine[field]
    if setting_define.type == "boolean" then
        local change,nv = widget.Checkbox(field,value)
        if change then
            self.com_setting:setv(path_tbl,field,nv)
        end
    elseif setting_define.type == "string" then
        local vt = {text = value}
        local change = widget.InputText(field,vt)
        if change then
            self.com_setting:setv(path_tbl,field,vt.text)
        end
    elseif setting_define.type == "enum" then
        local enumValue =  setting_define.enumValue
        if widget.BeginCombo(field,enumValue[value]) then
            for i,v in ipairs(enumValue) do
                if widget.Selectable(v,i == value) then
                    value = i
                    self.com_setting:setv(path_tbl,field,value)
                end
            end
            widget.EndCombo()
        end
    else
        assert(false,"Type not implement:"..setting_define.type)
    end
    cursor.SameLine()
    cursor.SetNextItemWidth(-1)
    if widget.Button("x") then
        self.com_setting:setv(path_tbl,field,nil)
    end
    widget.SetTooltip("Click to remove custom setting & use inherited value")
end

function GuiComponentStyle:_render_a_inherited_setting(from_path_tbl,target_path_tbl,field,value)
    local setting_define = SettingDefine[field]

    if setting_define.type == "boolean" then
        widget.Checkbox(field,value)
    elseif setting_define.type == "string" then
        local vt = {text = value}
        widget.InputText(field,vt)
    elseif setting_define.type == "enum" then
        local enumValue =  setting_define.enumValue
        if widget.BeginCombo(field,enumValue[value]) then
            for i,v in ipairs(enumValue) do
                widget.Selectable(v,i == value)
            end
            widget.EndCombo()
        end
    else
        assert(false,"Type not implement:"..setting_define.type)
    end
    cursor.SameLine()
    cursor.SetNextItemWidth(-1)
    if widget.Button("customize") then
        self.com_setting:setv(target_path_tbl,field,setting_define.defaultValue)
    end
    if util.IsItemHovered() then
        widget.SetTooltip("Click to use custom setting")
    end

    local pathdesc = ComponentSetting.Path2Desc(from_path_tbl)
    widget.TextDisabled(string.format("inherit from %s",pathdesc))
end

-------------------render tree------------------------------
function GuiComponentStyle:_init_schema_cfg()
    if not self.com_setting then
        --todo
        local thread = require "thread"
        local f = gui_util.open_current_pkg_path(DefaultPath,"rb")
        local packed_data = f:read("*all")
        f:close()
        local com_setting_data = thread.unpack(packed_data)
        self.com_setting = ComponentSetting.new("")
        self.com_setting:load_setting(self.schema_map,com_setting_data)
        self.sort_cfg = self.com_setting:get_sort_cfg()
        local sort_map = {}
        for i,v in ipairs(self.sort_cfg) do
            sort_map[v] = i
        end
        self.sort_map = sort_map
        assert(self.sort_cfg)
        self.path_tbl_cache = {}
    end
end

local function sort_pairs_schema(schema_map,sort_cfg)
    local index = 0
    local len = #sort_cfg
    return function()
        while true do
            index = index + 1
            if index > len then
                break
            end
            local name = sort_cfg[index]
            local schema = schema_map[name]
            if schema then
                return name,schema
            end
        end
    end

end

function GuiComponentStyle:_render_component_tree()
    local schema_map = self.schema_map
    self:_init_schema_cfg()

    for com_type,schema in sort_pairs_schema(schema_map,self.sort_cfg) do
        local path_tbl = self:_query_path_tbl(nil,schema)
        self:_render_component(com_type,com_type,schema,path_tbl,0)
    end
end

function GuiComponentStyle:_query_path_tbl( parent_path,schema)
    local name,type
    if schema._sortid then
        name = schema.name
        type = name
    else
        name = schema.name
        if schema.map or schema.array then
            type = nil
        else
            type = schema.type
        end
    end
    return ComponentSetting.CreateChildPath(parent_path,name,type)
end

function GuiComponentStyle:_render_component(com_name,com_type,ori_schema,path_tbl,indent)
    -- if child_only or widget.TreeNode(string.format("%s[%s]",com_name,com_type)) then
        local schema_map = self.schema_map
        local schema = schema_map[com_type]
        if not schema.type then
            self:_render_com_component(com_name,schema.name,ori_schema,path_tbl,indent)
        elseif schema.array then --array
            self:_render_array_component(com_name,schema.type,ori_schema,path_tbl,indent)
        elseif schema.map then --map false
            self:_render_map_component(com_name,schema.type,ori_schema,path_tbl,indent)
        elseif schema.type=="primtype" then-- false
            self:_render_primtype_component(com_name,schema.name,ori_schema,path_tbl,indent)
        else -- alias type 
            self:_render_alias_component(com_name,schema.name,ori_schema,path_tbl,indent)
        end
    -- end

end

--no type
function GuiComponentStyle:_render_com_component(com_name,com_type,ori_schema,path_tbl,indent)
    if self:TreeNode(com_name,com_type,ComSchemaType.Com,ori_schema,path_tbl,indent) then
        local schema_map = self.schema_map
        local next_indent = indent + 1
        local schema = schema_map[com_type]
        for i,child_schema in ipairs(schema) do
            local typ = child_schema.type
            local name = child_schema.name
            -- local child_real_schema = schema_map[typ]
            local child_path_tbl = self:_query_path_tbl(path_tbl,child_schema)
            if child_schema.array then --array
                self:_render_array_component(name,typ,child_schema,child_path_tbl,next_indent)
            elseif child_schema.map then --map false
                self:_render_map_component(name,typ,child_schema,child_path_tbl,next_indent)
            else -- alias type 
                self:_render_component(name,typ,child_schema,child_path_tbl,next_indent)
            end
        end
        self:TreePop()
    end
end

function GuiComponentStyle:_render_array_component(com_name,com_type,ori_schema,path_tbl,indent)
    if self:TreeNode(com_name,com_type,ComSchemaType.Array,ori_schema,path_tbl,indent) then
        --todo
        local schema_map = self.schema_map 
        local child_schema = schema_map[com_type]
        local child_path_tbl = self:_query_path_tbl(path_tbl,child_schema)
        self:_render_component(child_schema.name,child_schema.name,child_schema,child_path_tbl,indent+1)
        self:TreePop()
    end
end

function GuiComponentStyle:_render_map_component(com_name,com_type,ori_schema,path_tbl,indent)
    if self:TreeNode(com_name,com_type,ComSchemaType.Map,ori_schema,path_tbl,indent) then
        --todo
        local schema_map = self.schema_map
        local child_schema = schema_map[com_type]
        local child_path_tbl = self:_query_path_tbl(path_tbl,child_schema)
        self:_render_component(child_schema.name,child_schema.name,child_schema,child_path_tbl,indent+1)
        self:TreePop()
    end
end

function GuiComponentStyle:_render_primtype_component(com_name,com_type,ori_schema,path_tbl,indent)
    if self:TreeNode(com_name,com_type,ComSchemaType.Prim,ori_schema,path_tbl,indent,true) then
        self:TreePop()
    end
end

function GuiComponentStyle:_render_alias_component(com_name,com_type,ori_schema,path_tbl,indent)
    local schema_map = self.schema_map
    local source_schema = schema_map[com_type]
    local source_type = source_schema.type
    self:_render_component(com_name,source_type,ori_schema,path_tbl,indent)
end

-------------------render tree------------------------------


function GuiComponentStyle:TreeNode(show_name,com_type,schema_type,schema,path_tbl,indent,is_leaf)
    -- local flag = flags.TreeNode.OpenOnDoubleClick
    local flag = 0
    if is_leaf then
        flag = flags.TreeNode {"Bullet"}
    end
    
    local com_name = nil
    if schema._sortid then
        com_name = schema.name
    end
    -- if not schema._sortid then
    --     com_name = schema.type
    -- end
    local open = widget.TreeNode(show_name,flag)
    if util.IsItemClicked() and  util.IsItemActive() then
        self.selected = self.selected or {}
        self.selected.schema = schema
        self.selected.path_tbl = path_tbl
        self.selected.type = com_type
    end
    local on_dragdrop = false
    if com_name and indent == 0 then
        -- local drag_type = string.format("ComponentItem_%d",indent)
        local drag_type = "ComponentItem"
        if widget.BeginDragDropSource() then
            widget.SetDragDropPayload(drag_type,com_name)
            if widget.TreeNode(show_name,flag) then
                on_dragdrop = true
                open = not open
                widget.TreePop()
            end
            widget.EndDragDropSource()
        end
        local my_index = self.sort_map[com_name]
        if widget.BeginDragDropTarget() then
            local data = widget.AcceptDragDropPayload(drag_type,flags.DragDrop.AcceptBeforeDelivery)
            if data then
                on_dragdrop = true
                -- print(data)
                local source_com = data
                local source_index = self.sort_map[source_com]
                if source_com ~= com_name and my_index ~= source_index then
                    
                    -- print(source_index,source_com,my_index,com_name)
                    self.sort_map[source_com] = my_index
                    self.sort_map[com_name] = source_index
                    self.com_setting:swap_sort(source_index,my_index)
                    -- print_a("after swap",self.sort_cfg[source_index],self.sort_cfg[my_index])
                end
            end
            widget.EndDragDropTarget()
        end
    end
    if (not on_dragdrop) and util.IsItemHovered() then
        local tips_str = "Component Type:%s\nComponent Name:%s"
        if schema_type == ComSchemaType.Map then
            tips_str = "Component Type:[map of %s]\nComponent Name:%s"
        elseif schema_type == ComSchemaType.Array then
            tips_str = "Component Type:[array of %s]\nComponent Name:%s"
        elseif schema_type == ComSchemaType.Prim then
            tips_str = "Component Type:%s\nComponent Name:%s"
        end
        widget.SetTooltip(string.format(tips_str,com_type,com_name or "Not A Component"))
    end
    return open
end

function GuiComponentStyle:TreePop()
    widget.TreePop()
end


return GuiComponentStyle