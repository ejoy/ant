local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local IO      = imgui.IO
local hub       = import_package "ant.editor".hub
local ComponentSetting = require "editor.component_setting"
local factory = require "widget.gui_basecomponent_widget"

local class     = require "common.class"
local GuiEntityWidget = class("GuiEntityWidget")



local is_direct_type

local DefaultOpen = flags.TreeNode.DefaultOpen

function GuiEntityWidget:_init()
    self.schema = nil
    self.com_setting = nil
    self.path_tbl_cache = {}
end

function GuiEntityWidget:set_schema(schema)
    self.schema = schema
    self.path_tbl_cache = {}
end

function GuiEntityWidget:set_com_setting(com_setting)
    self.com_setting = com_setting
    if self._last_entity then
        self:_refresh_sorted_entity(self._last_entity)
    end
end

function GuiEntityWidget:set_change_cb(cb,obj)
    if obj then
        local obj_cb = function(...)
            cb(obj,...)
        end
        self.change_cb = obj_cb
    else
        self.change_cb = cb
    end
end

function GuiEntityWidget:set_debug_mode(val)
    self.debug_mode = val
end

local donothing = function() end
function GuiEntityWidget:CustomTreeNode(name,path_tbl,typ)
    local cfg = self.com_setting:get_com_cfg(path_tbl,typ)
    if cfg.DisplayName and cfg.DisplayName ~= "" then
        name = cfg.DisplayName
    end
    if cfg.NameFormat and cfg.NameFormat ~= "" then
        name = string.format(cfg.NameFormat,name)
    end
    local flag = 0
    if cfg.DefaultOpen then
        flag = DefaultOpen
    end
    if cfg.HideHeader then
        local schema = path_tbl[1].type and self.schema[path_tbl[1].type]
        if schema then
            --XOR(schema.multiple,typ == ComponentSetting.ComType.Multiple)
            if (not schema.multiple) ~= ( typ == ComponentSetting.ComType.Multiple) then
                return true,donothing
            end
            if schema.multiple then
                --name is index
                if cfg.IndexFormat and cfg.IndexFormat ~= "" then
                    name = string.format(cfg.IndexFormat,name)
                end
            end
        else
            return true,donothing
        end
    end
    path_tbl.__ui_cache = path_tbl.__ui_cache or {}
    local ui_cache = path_tbl.__ui_cache[name] or {}
    path_tbl.__ui_cache[name] = ui_cache
    if ui_cache.opened == nil then
        ui_cache.opened = true
    end
    windows.PushStyleVar(enum.StyleVar.ItemInnerSpacing,0,0)
    windows.PushStyleVar(enum.StyleVar.ItemSpacing,0,0)
    local change = widget.Selectable(name,false,nil,nil,flags.Selectable.SpanAllColumns)
    if change then
        ui_cache.opened = not ui_cache.opened
    end
    cursor.SameLine()
    if change then
        widget.SetNextItemOpen(ui_cache.opened)
    end 
    windows.PopStyleVar(2)
    local end_func = function()
        widget.TreePop()
    end
    return widget.TreeNode("##"..name,flag),end_func
end

function GuiEntityWidget:create_child_path( parent_path,schema)
    local cache = nil
    repeat
        cache = self.path_tbl_cache[parent_path or 1]
        if not cache then
            cache = {}
            self.path_tbl_cache[parent_path or 1] = cache
            break
        end
        local child_path = cache[schema]
        if not child_path then
            break
        end
        return child_path
    until true
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
    local child_path = ComponentSetting.CreateChildPath(parent_path,name,type)
    cache[schema] = child_path
    return child_path
end

function GuiEntityWidget:on_base_component_change(eid,com_id,name,value)
    if self.change_cb then
        return self.change_cb(eid,com_id,name,value)
    end
end

function GuiEntityWidget:render_base_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    local schema = self.schema
    -- local com_schema = schema[com_name]
    -- local typ = com_schema.type
    local base_widget = factory[com_name]
    local value = component_data
    local ui_cache = parent_tbl.__ui_cache or {}
    parent_tbl.__ui_cache = ui_cache
    local cfg = self.com_setting:get_com_cfg(path_tbl,ComponentSetting.ComType.Normal)
    local display_name = alias_name
    if cfg.DisplayName and cfg.DisplayName ~= "" then
        display_name = cfg.DisplayName
    end

    local change,new_value,editing =  base_widget(ui_cache,display_name,value,cfg)
    self.is_editing = self.is_editing or editing
        --todo something
    if change then
        log.trace_a("base_component",display_name,new_value)
        parent_tbl[alias_name] = new_value
        local eid = parent_tbl.__id
        if not eid then
            --entity has nor __id,but has __entity_id
            eid = parent_tbl.__entity_id
        end
        self:on_base_component_change(eid,parent_tbl.__id,alias_name,new_value)

        --todo
        -- entity_property_builder.notify_modify(eid,parent_tbl.__id,alias_name,value)
        --return true -- if return nil, modify will be ignored
    end
    if self.debug_mode then
        if util.IsItemHovered() then
            local tips = string.format("data:\n%s\npath:\n%s",
                dump_a({component_data},"\t"),
                dump_a({path_tbl},"\t"))
            widget.SetTooltip(tips)
        end
    end
    return true
end

function GuiEntityWidget:render_alias_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    local schema = self.schema
    local com_schema = schema[com_name]
    local map_com_type = com_schema.type
    return self:render_component(parent_tbl,map_com_type,component_data,alias_name,path_tbl)
end

function GuiEntityWidget:render_array_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    local schema = self.schema
    local com_schema = schema[com_name]
    local map_com_type = com_schema.type
    local array_param = com_schema.array
    local typ = map_com_type
    if typ == nil or typ == "primtype" then
        typ = com_name
    end
    local cfg = self.com_setting:get_com_cfg(path_tbl,ComponentSetting.ComType.Array)
    if cfg.ArrayAsVector then
        self:render_base_component(parent_tbl,"vector",component_data,alias_name,path_tbl)
    else
        local show,popfunc = self:CustomTreeNode(alias_name,path_tbl,ComponentSetting.ComType.Array)
        if show then
            local child_path_tbl = self:create_child_path(path_tbl,schema[typ])
            
            local len = #component_data
            for index,data in ipairs(component_data) do
                self:render_component(component_data,typ,data,index,child_path_tbl)
            end
            popfunc()
        end
    end
    return true
end

function GuiEntityWidget:render_map_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    local schema = self.schema
    local com_schema = schema[com_name]
    -- local map_com_type = com_schema.type
    -- local map = com_schema.map
    local show,pop_func = self:CustomTreeNode(alias_name,path_tbl,ComponentSetting.ComType.Map)
    if show then
        for child_name,data in pairs(component_data) do
            local child_path_tbl = self:create_child_path(path_tbl,com_schema)
            self:render_component(component_data,com_name,data,child_name,child_path_tbl)
        end
        pop_func()
    end
    return true
end

function GuiEntityWidget:render_com_component( parent_tbl,com_name,component_data,alias_name,path_tbl)
    local schema = self.schema
    local show,pop_func = self:CustomTreeNode(alias_name,path_tbl,ComponentSetting.ComType.Com)
    if show then
        local com_schema = schema[com_name]
        local count = 0
        for _,sub_schema in ipairs(com_schema) do
            local sub_data = component_data[sub_schema.name]
            if component_data[sub_schema.name] then
                local child_ctrl = nil
                local child_path_tbl = self:create_child_path(path_tbl,sub_schema)
                if not sub_schema.type then
                    self:render_com_component(component_data,sub_schema.type,sub_data,sub_schema.name,child_path_tbl)
                elseif sub_schema.array then -- has type & array
                    self:render_array_component(component_data,sub_schema.type,sub_data,sub_schema.name,child_path_tbl)
                elseif sub_schema.map then -- has type & map
                    self:render_map_component(component_data,sub_schema.type,sub_data,sub_schema.name,child_path_tbl)
                elseif  is_direct_type(sub_schema.type)  then
                    self:render_base_component(component_data,sub_schema.type,sub_data,sub_schema.name,child_path_tbl)
                else -- has type & not array
                    self:render_component(component_data,sub_schema.type,sub_data,sub_schema.name,child_path_tbl)
                end
                count = count + 1
            end
        end
        pop_func()
    end
    return true
end

function GuiEntityWidget:render_multiple_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    local schema = self.schema
    local com_schema = schema[com_name]
    local map_com_type = com_schema.type
    local typ = map_com_type
    if typ == nil or typ == "primtype" then
        typ = com_name
    end
    local show_main,popfunc_main = self:CustomTreeNode(alias_name,path_tbl,ComponentSetting.ComType.Multiple)
    if show_main then
        local len = #component_data
        for index,data in ipairs(component_data) do
            self:render_component(component_data,typ,data,index,path_tbl,true)
            if index ~= #component_data then
                cursor.Separator()
            end
        end
        popfunc_main()
    end
    return true
end

function GuiEntityWidget:render_component(parent_tbl,com_name,component_data,alias_name,path_tbl,ignore_multiple)
    local schema = self.schema
    local com_schema = schema[com_name]
    if is_direct_type(com_name) then
        return self:render_base_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    elseif not com_schema then
        widget.Text("not found component schema:"..com_name)
        return false
    elseif com_schema.multiple and ( not ignore_multiple) then
        return self:render_multiple_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    elseif not com_schema.type then
        return self:render_com_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    elseif com_schema.array then
        return self:render_array_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    elseif com_schema.map then -- has type & map
        return self:render_map_component(component_data,sub_schema.type,sub_data,sub_schema.name,path_tbl)
    else -- has type & not array
        return self:render_alias_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    end
end

function is_direct_type(type)
    return factory[type]
end

function GuiEntityWidget:_refresh_sorted_entity(entity)
    assert(self.com_setting)
    local sort_cfg = self.com_setting:get_sort_cfg()
    local sorted_entity = {}
    for i,com_name in ipairs(sort_cfg) do
        if entity[com_name] ~= nil then
            table.insert(sorted_entity,{com_name=com_name,data = entity[com_name]})
        end
    end
    self._sorted_entity = sorted_entity
    self._last_entity = entity
end

function GuiEntityWidget:update(eid,entity,base_component_cache)
    local schema = self.schema
    entity.__entity_id = eid
    if self._last_entity ~= entity then
        self:_refresh_sorted_entity(entity)
    end
    self.is_editing = false
    factory.BeginProperty(base_component_cache)
    for i,data in ipairs(self._sorted_entity) do
        local com_name = data.com_name 
        local component_data = data.data
        if com_name ~= "__entity_id" and com_name ~= "__ui_cache" then
        -- if widget.CollapsingHeader(com_name.."##RootComponent") then
            local path_tbl = self:create_child_path(nil,schema[com_name])
            if self:render_component(entity,com_name,component_data,com_name,path_tbl) then
            -- end
                cursor.Separator()
            end
        end
    end
    factory.EndProperty()
    if self.debug_mode then
        widget.Text(dump_a({entity},"\t"))
    end
end

return GuiEntityWidget