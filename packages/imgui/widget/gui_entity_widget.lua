local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local IO        = imgui.IO
local hub       = import_package "ant.editor".hub
local Event     = require "hub_event"

local ComponentSetting = require "editor.component.component_setting"
local factory = require "widget.gui_basecomponent_widget"

local class     = require "common.class"
local GuiEntityWidget = class("GuiEntityWidget")

local function table_list_get(table_list,key)
    local value_list = {}
    for i,tbl in ipairs(table_list) do
        local value = tbl[key]
        if value then
            table.insert(value_list,value)
        else
            return false
        end
    end
    return value_list
end

local function table_list_set_single(table_list,key,value)
    for i,tbl in ipairs(table_list) do
        tbl[key] = value
    end
end
local function table_list_set_list(table_list,key,value_list)
    assert((#table_list)<=(#value_list))
    for i,tbl in ipairs(table_list) do
        tbl[key] = value_list[i]
    end
end

local is_direct_type

local DefaultOpen = flags.TreeNode.DefaultOpen

function GuiEntityWidget:_init()
    self.schema = nil
    self.com_setting = nil
    self.path_tbl_cache = {}
    self.state = "single" -- or "mult"
    self.cur_eids = nil
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

function GuiEntityWidget:set_change_cb(cb,mult_cb,obj)
    if obj then
        local obj_cb = function(...)
            cb(obj,...)
        end
        self.change_cb = obj_cb
        local mult_obj_cb = function(...)
            mult_cb(obj,...)
        end
        self.mult_change_cb = mult_obj_cb
    else
        self.change_cb = cb
        self.mult_change_cb = mult_cb
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
    if schema.package then
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

function GuiEntityWidget:on_base_component_change(eid,seid,com_id,name,value)
    if self.change_cb then
        return self.change_cb(eid,seid,com_id,name,value)
    end
end

function GuiEntityWidget:on_mult_component_change(eids,seids,com_ids,name,value,is_list)
    if self.mult_change_cb then
        return self.mult_change_cb(eids,seids,com_ids,name,value,is_list)
    end
end

function GuiEntityWidget:render_base_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    local schema = self.schema
    -- local com_schema = schema[com_name]
    -- local typ = com_schema.type
    local value = component_data
    local ui_cache = parent_tbl.__ui_cache or {}
    parent_tbl.__ui_cache = ui_cache
    local cfg = self.com_setting:get_com_cfg(path_tbl,ComponentSetting.ComType.Normal)
    local display_name = alias_name
    if cfg.DisplayName and cfg.DisplayName ~= "" then
        display_name = cfg.DisplayName
    end
    local change,new_value,editing
    if self.state == "single" then
        local base_widget = factory.single[com_name]
        change,new_value,editing =  base_widget(ui_cache,display_name,value,cfg)
    else
        local base_widget = factory.mult[com_name]
        change,new_value,editing =  base_widget(ui_cache,display_name,value,cfg)
    end

    self.is_editing = self.is_editing or editing
        --todo something
    if change then
        log.trace_a("base_component",display_name,new_value)
        if self.state == "single" then
            parent_tbl[alias_name] = new_value
            local seid = parent_tbl.__id
            if not seid then
                --entity has nor __id,but has __entity_id
                seid = parent_tbl.__entity_id
            end
            self:on_base_component_change(self.cur_eids[1],seid,parent_tbl.__id,alias_name,new_value)
        else --mult
            local com_ids = table_list_get(parent_tbl,"__id")
            local seids
            if not com_ids then
                seids = table_list_get(parent_tbl,"__entity_id")
            end
            local is_list = factory.WillReturnList[com_name]
            if is_list then
                table_list_set_list(parent_tbl,alias_name,new_value)
            else
                table_list_set_single(parent_tbl,alias_name,new_value)
            end
            self:on_mult_component_change(self.cur_eids,com_ids or seids,com_ids,alias_name,new_value,is_list)
        end

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
        if self.state == "mult" then
            widget.Text("Array cannot be mult-edited.")
        else
            local show,popfunc = self:CustomTreeNode(alias_name,path_tbl,ComponentSetting.ComType.Array)
            if show then
                local child_path_tbl = self:create_child_path(path_tbl,schema[typ])
                for index,data in ipairs(component_data) do
                    self:render_component(component_data,typ,data,index,child_path_tbl)
                end
                popfunc()
            end
        end
    end
    return true
end

function GuiEntityWidget:render_map_component(parent_tbl,com_name,component_data,alias_name,path_tbl)
    local schema = self.schema
    local com_schema = schema[com_name]
    -- local map_com_type = com_schema.type
    -- local map = com_schema.map
    if self.state == "mult" then
        widget.Text("Map cannot be mult-edited.")
    else
        local show,pop_func = self:CustomTreeNode(alias_name,path_tbl,ComponentSetting.ComType.Map)
        if show then
            for child_name,data in pairs(component_data) do
                local child_path_tbl = self:create_child_path(path_tbl,com_schema)
                self:render_component(component_data,com_name,data,child_name,child_path_tbl)
            end
            pop_func()
        end
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
            local sub_data = nil
            if self.state == "mult" then
                sub_data = table_list_get(component_data,sub_schema.name)
            else
                sub_data = component_data[sub_schema.name]
            end
            if sub_data then
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
    if self.state == "mult" then
        widget.Text("Map cannot be mult-edited.")
    else
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
    return factory.single[type]
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
    self._sorted_coms = sorted_entity
    self._last_entity = entity
end

function GuiEntityWidget:_refresh_sorted_entity_mult(eids,entities,entitys)
    assert(self.com_setting)
    local sort_cfg = self.com_setting:get_sort_cfg()
    local entity_list = {}
    for i,eid in ipairs(eids) do
        table.insert(entity_list,entities[eid])
    end
    local sorted_coms_mult = {}
    for i,com_name in ipairs(sort_cfg) do
        local all_has = true
        for i,entity in ipairs(entity_list) do
            if not entity[com_name] then
                all_has = false
                break
            end
        end
        if all_has then
            local datas = {}
            for i,entity in ipairs(entity_list) do
                table.insert(datas,entity[com_name])
            end
            table.insert(sorted_coms_mult,{com_name=com_name,datas = datas})
        end
    end

    self._entity_list = entity_list
    self._sorted_coms_mult = sorted_coms_mult
    self._last_eids = eids
end

function GuiEntityWidget:update(eids,entities,base_component_cache,policy)
    if #eids == 1 then
        if self.state ~= "single" then
            self:clear_mult_temp()
            self.state = "single"
        end
        widget.Text(self.state)
        self:update_single(eids,entities,base_component_cache,policy)
    else
         if self.state ~= "mult" then
            self:clear_single_temp()
            self.state = "mult"
        end
        widget.Text(self.state)
        assert(#eids > 1,"GuiEntityWidget:update eids is empty")
        self:update_mult(eids,entities,base_component_cache)
    end
end

function GuiEntityWidget:clear_single_temp()
    self._sorted_coms = nil --{{com1_name,com1_data1},{com2_name,com2_data}}
    self._last_entity = nil
end

function GuiEntityWidget:clear_mult_temp()
    self._entity_list = nil -- {entity1,entity2,...}
    self._sorted_coms_mult = nil --{{com1_name,{com1_data1,com1_data2}},{com2_name,{com2_data1,com2_data2}}}
    self._last_eids = nil --eids
end 

function GuiEntityWidget:update_single(eids,entities,base_component_cache,policy_dic)
    local schema = self.schema
    local first_eid = eids[1]
    local entity = entities[first_eid]
    self.cur_eids = eids
    assert(entity)
    entity.__entity_id = first_eid
    if self._last_entity ~= entity then
        self:_refresh_sorted_entity(entities[first_eid])
    end
    self.is_editing = false
    self:update_policy(first_eid,policy_dic,entities,base_component_cache)
    factory.BeginProperty(base_component_cache)
    for i,data in ipairs(self._sorted_coms) do
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

function GuiEntityWidget:update_policy(eid,policy_dic,entity_dic,cache)
    if widget.CollapsingHeader("Policy") then
        -- local policy = policy_dic[eid]
        -- log.info_a(">>",eid,policy_dic)
        local policy = policy_dic[eid]
        cache.policy = cache.policy or {
            select_index = nil
        }
        cursor.Indent()
        for i in ipairs(policy) do
            local selected =( i==cache.policy.select_index )
            if widget.Selectable(policy[i],selected) then
                if selected then
                    cache.policy.select_index = nil
                else
                    cache.policy.select_index = i
                end
            end
            self:show_policy_menu(i,eid,policy[i],policy_dic,entity_dic)
        end
        cursor.Unindent()
        cursor.Separator()
    end
end

function GuiEntityWidget:show_policy_menu(id,eid,policy_name,policy_dic,entity_dic)
    local open = windows.BeginPopupContextItem("Selected_Menu###"..id,1)
    if open then
        if widget.Button("Add Policy") then
            hub.publish(Event.ETE.OpenAddPolicyView,{eid},policy_dic)
        end
        windows.EndPopup()
    end
    return open
end


function GuiEntityWidget:update_mult(eids,entities,base_component_cache)
    local schema = self.schema
    assert(entities)
    for eid,entity in pairs(entities) do
        entity.__entity_id = eid
    end
    if self._last_eids ~= eids then
        self:_refresh_sorted_entity_mult(eids,entities)
    end
    self.cur_eids = eids
    self.is_editing = false
    local entity_list = self._entity_list
    local sorted_coms_mult = self._sorted_coms_mult
    factory.BeginProperty(base_component_cache)
    for i,data in ipairs(sorted_coms_mult) do
        local com_name = data.com_name
        local component_datas = data.datas
        if com_name ~= "__entity_id" and com_name ~= "__ui_cache" then
        -- if widget.CollapsingHeader(com_name.."##RootComponent") then
            local path_tbl = self:create_child_path(nil,schema[com_name])
            if self:render_component(entity_list,com_name,component_datas,com_name,path_tbl) then
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