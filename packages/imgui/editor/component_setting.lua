local SettingDefine = require "editor.component_setting_define"
local class = require "common.class"

local function TAppend(a,b)
    for i,v in ipairs(b) do
        table.insert(a,v)
    end
end

local NormalCfgList = {
    "DefaultOpen","DisplayName",
}

local ArrayCfgList = {
    "ArrayStyle",
}
TAppend(ArrayCfgList,NormalCfgList)

local MapCfgList = {
}
TAppend(MapCfgList,NormalCfgList)

local ComCfgList = {
    
}
TAppend(ComCfgList,NormalCfgList)

local CfgList = {
    Normal = NormalCfgList,
    Array = ArrayCfgList,
    Map = MapCfgList,
    Com = ComCfgList,
}


local ComponentSetting = class("ComponentSetting")
ComponentSetting.CfgList = CfgList


function ComponentSetting:_init(cfg_path)
    self.cfg_path = cfg_path
    self.dirty = false
    self.com_setting = nil
    self.global_setting = nil
    self.default_setting = nil
    self:_init_default_setting()
end

function ComponentSetting:_init_default_setting()
    local setting = {}
    for field,define in pairs(SettingDefine) do
        setting[field] = define.defaultValue
    end
    self.default_setting = setting
    print_a("default_setting",self.default_setting)
end

function ComponentSetting:load_setting(schema_map,data)
    self.dirty = false
    --merge DefaultComponentSetting
    self.com_setting = data.com_setting or {setting={},children={}}
    self.sort_cfg = data.sort_cfg or {}
    self.global_setting = self.com_setting.setting
    -- setmetatable(self.global_setting,{__index=DefaultComponentSetting})
    --use schema_map
    self:_update_sort_cfg(schema_map)
end

function ComponentSetting:_update_sort_cfg(schema_map)
    self.sort_cfg = self.sort_cfg or {}
    local sort_map = {}
    for k,v in ipairs(self.sort_cfg) do
        sort_map[v] = k 
    end
    local rest_name_list = {}
    for k,_ in pairs(schema_map) do
        if not sort_map[k] then
            table.insert(rest_name_list,k)
        end
    end
    table.sort(rest_name_list)
    for _,v in ipairs(rest_name_list) do
        table.insert(self.sort_cfg,v)
    end
end

function ComponentSetting:swap_sort( index_a,index_b )
    self.sort_cfg[index_a],self.sort_cfg[index_b] = self.sort_cfg[index_b],self.sort_cfg[index_a]
end

--return data_tbl
function ComponentSetting:get_save_data()
    return {
        com_setting = self.com_setting, 
        sort_cfg    = self.sort_cfg,
    }
end

--return setting_tbl,path_tbl
--if returned path_tbl ~= path_tbl in arg ,then means setting_tbl is inherited from the returned path_tbl
function ComponentSetting:_get_setting_by_path(path_tbl,create_if_nil,key)
    local root = self.com_setting
    local com_setting = self.com_setting
    if not create_if_nil then
        if path_tbl == nil then
            if com_setting.setting[key] then
                return self.global_setting,{} -- return default setting
            else
                assert(self.default_setting[key]~=nil)
                return self.default_setting,nil
            end
        end
        local cur_tbl = path_tbl
        local cur_setting_tbl = com_setting
        local name = cur_tbl[1].type
        if name then
            while true do
                local children_setting = cur_setting_tbl.children
                if not children_setting then
                    return self:_get_setting_by_path(path_tbl[2],false,key)
                end
                local cur_setting_tbl = children_setting[name]
                if not cur_setting_tbl then
                    return self:_get_setting_by_path(path_tbl[2],false,key)
                end

                cur_tbl = cur_tbl[2]
                if not cur_tbl then break end
                name = cur_tbl[1].name or cur_tbl[1].type
            end
            if ( not cur_setting_tbl.setting ) or ( cur_setting_tbl.setting[key] == nil ) then
                return self:_get_setting_by_path(path_tbl[2],false,key)
            end
        else
            return self:_get_setting_by_path(path_tbl[2],false,key)
        end
        return cur_setting_tbl.setting,path_tbl
    else
        local cur_tbl = path_tbl
        local cur_setting_tbl = com_setting
        local name = cur_tbl[1].type
        assert(name)
        while true do
            local children_setting = cur_setting_tbl.children
            if not children_setting then
                children_setting = {}
                cur_setting_tbl.children = children_setting
                self.dirty = true
            end
            local cur_setting_tbl = children_setting[name]
            if not cur_setting_tbl then
                cur_setting_tbl = {}
                children_setting[name] = cur_setting_tbl
                self.dirty = true
            end
            cur_tbl = cur_tbl[2]
            if not cur_tbl then break end
            name = cur_tbl[1].name or cur_tbl[1].type
        end
        cur_setting_tbl.setting = cur_setting_tbl.setting or {}
        return cur_setting_tbl.setting,path_tbl
    end
end

--path_tbl:point to component,like
--(so path_tbl = path_tbl[2] means remove headnode)
-- { 
--     1 = {name = "pickup_material",type="pickup_material"},
--     2 = {
--         1= {name = "opaque",type="material_content"},
--         2= {
--             1 = {name = "ref_path",type="respath"},
--         }
--     }
-- }
--1->parent,2->self
--return value,[ source_path_tbl if inherited,otherwise nil]
function ComponentSetting:getv(path_tbl,key)
    --get from setting,if not found,get from self.default setting
    local setting,source_path_tbl = self:_get_setting_by_path(path_tbl,false,key)
    local value = setting[key]
    assert(value~=nil)
    return value,source_path_tbl
end

function ComponentSetting:setv(path_tbl,k,v)
    --once,value will set into setting,don't use default now
    local setting,source_path_tbl = self:_get_setting_by_path(path_tbl,true)
    if setting[k] == v then
        return
    else
        setting[k] = v
        self.dirty = true
    end
end

function ComponentSetting:get_sort_cfg()
    return self.sort_cfg
end

function ComponentSetting.CreateChildPath(parent,child_name,child_type)
    local result = {}
    local child_path = result
    while parent and parent[1] do
        child_path[1] = parent[1]
        parent = parent[2]
        child_path[2] = {}
        child_path = child_path[2]
    end
    child_path[1] ={name=child_name,type = child_type}
    return result
end

function ComponentSetting.Path2Desc(path_tbl)
    if path_tbl == nil then
        return "Default Value"
    elseif path_tbl[1] == nil then
        return "Global Setting"
    end
    local con = {}
    while path_tbl[1] do
        table.insert(con,path_tbl[1].name)
    end
    return table.concat(con,".")
end

return ComponentSetting