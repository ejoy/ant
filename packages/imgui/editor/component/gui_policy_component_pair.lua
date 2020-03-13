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

local SingleStateColor = {
    {"normal","input","output"},
    normal = {0.4,0.7,0,1},
    input = {255,0.6,0.6,1},
    output = {255,0,0.1,1},
}
local MultStateColor = {
    {"normal","conflict"},
    normal = {0.4,0.7,0,1},
    conflict = {255,0,0.1,1},
}
--Todo:
    --增加规则：同group的冲突，目前还没需要，都有output约束；
    --Policy增加依赖关系；
local GuiPolicyComponentPair = GuiBase.derive("GuiPolicyComponentPair")
GuiPolicyComponentPair.GuiName = "PolicyComponentPair"
function GuiPolicyComponentPair:_init()
    GuiBase._init(self)
    self.default_size = {560,820}
    self._is_opened = false
    self.title_id = "PolicyComponentPair"
    self.schema_map = self:get_schema_map()--{policies={},components={},transforms={}}
    self.selected_map = {
        policy = {},
        component = {},
    }
    self.pairs_map = {
        policy = nil,
        component = nil
    }
    self.cur_selected_type = nil--"policy"/"component"/nil
    self.cur_selected_mult = false -- true/false
    self.cache = nil
end

function GuiPolicyComponentPair:get_schema_map()
    local util = require "editor.gui_util"
    local schema_map = util.get_all_schema()
    return schema_map
end

function GuiPolicyComponentPair:init_cache()
    local cache = {}
    --create sorted list
    do
        cache.sorted = {}
        local policies = self.schema_map.policies
        local policy_names = {}
        for k,_ in pairs(policies) do
            table.insert(policy_names,k)
        end
        table.sort(policy_names)
        cache.sorted.policies = policy_names
        local components = self.schema_map.components
        local component_names = {}
        for k,_ in pairs(components) do
            table.insert(component_names,k)
        end
        table.sort(component_names)
        cache.sorted.components = component_names
    end

    --pairs_cache
    -- component = {
    --     policy = "output"/"input"/"normal"
    -- }
    -- policy = {
    --     parent = "",
        -- transforms = [
        --     {
        --         name = name,
        --         output = [],
        --         input = [],
        --     }
        -- ]
            
    --     components = {
    --         component = "output"/"input"/"normal",
    --     }
    -- }
    do
        local policies = self.schema_map.policies
        local components = self.schema_map.components
        local transform_dic = self.schema_map.transforms
        local component_tbl = {}
        local policy_tbl = {}
        cache.component_tbl = component_tbl
        cache.policy_tbl = policy_tbl
        for pname,policy_data in pairs(policies) do
            local policy_info = {}
            policy_tbl[pname] = policy_info
            local require_transform = policy_data.require_transform --list
            local require_component = policy_data.require_component --list
            local unique_component = policy_data.unique_component --list
            policy_info.components = {}
            policy_info.is_unique = {}
            if require_component then
                for _,c in ipairs(require_component) do
                    policy_info.components[c] = "normal"
                end
            end
            if unique_component then
                for _,c in ipairs(unique_component) do
                    policy_info.components[c] = "normal"
                    policy_info.is_unique[c] = true
                end
            end

            if require_transform then
                policy_info.transforms = {} --
                for _,tname in ipairs(require_transform) do
                    local _p, _name = tname:match "^([^|]*)|(.*)$"
                    _name = _name or tname
                    local tdata = transform_dic[_name]
                    local temp = {
                        name = _name,
                        output = tdata.output,
                        input = tdata.input,
                    }
                    for _,cname in ipairs(tdata.output or {}) do
                        policy_info.components[cname] = "output"
                    end
                    for _,cname in ipairs(tdata.input or {}) do
                        if policy_info.components[cname]~="output" then
                            policy_info.components[cname] = "input"
                        end
                    end
                    table.insert(policy_info.transforms,temp)
                end
            end
            for cname,ctype in pairs(policy_info.components) do
                component_tbl[cname] = component_tbl[cname] or {}
                component_tbl[cname][pname] = ctype
            end
            policy_info.require_package = policy_data.require_package
            policy_info.require_system = policy_data.require_system
            policy_info.require_policy = policy_data.require_policy
            policy_info.defined = policy_data.defined
            policy_info.package = policy_data.package
        end

    end

    self.cache = cache
end

function GuiPolicyComponentPair:on_update()
    if not self.cache then
        self:init_cache()
    end
    self:update_top()
    --top,2 childwindow
    local w,_ = windows.GetContentRegionAvail()
    --left policy
    windows.PushStyleColor(enum.StyleCol.MenuBarBg,0.13,0.25,0.38,1)
    if windows.BeginChild("left",w*0.5,0,true,flags.Window.MenuBar) then
        if widget.BeginMenuBar() then
            widget.Text("Policy")
            cursor.SameLine()
            local avail_w,_ = windows.GetContentRegionAvail()
            cursor.Dummy(avail_w-100,0)
            if widget.Button("SelectAll",-1) then
                self:on_select_all("policy")
            end
            widget.EndMenuBar()
        end

        local policies = self.schema_map.policies
        local selected_map = self.selected_map["policy"]
        local sorted_names = self.cache.sorted.policies
        local policy_pair = self.pairs_map.policy
        for _,name in ipairs(sorted_names) do
            if policy_pair and policy_pair[name] then
                self:policy_selectable(name,selected_map[name])
            end
        end
        for _,name in ipairs(sorted_names) do
            if not (policy_pair and policy_pair[name]) then
                self:policy_selectable(name,selected_map[name])
            end
        end
    end
    windows.EndChild()
    windows.PopStyleColor()
    --right component
    cursor.SameLine()
    local start,_ = cursor.GetCursorPos()
    windows.PushStyleColor(enum.StyleCol.MenuBarBg,0.13,0.25,0.38,1)
    if windows.BeginChild("right",w-start,0,true,flags.Window.MenuBar) then
        if widget.BeginMenuBar() then
            widget.Text("Component")
            widget.EndMenuBar()
        end
        local components = self.schema_map.components
        local selected_map = self.selected_map["component"]
        local sorted_names = self.cache.sorted.components
        local component_pair = self.pairs_map.component
        for _,name in ipairs(sorted_names) do
            if component_pair and component_pair[name] then
                self:component_selectable(name,selected_map[name])
            end
        end
        for _,name in ipairs(sorted_names) do
            if not ( component_pair and component_pair[name]) then
                self:component_selectable(name,selected_map[name])
            end
        end

    end
    windows.EndChild()
    windows.PopStyleColor()

end

function GuiPolicyComponentPair:update_top()
    local w,_ = windows.GetContentRegionAvail()
    if windows.BeginChild("top",w,54,true) then
        if self.cur_selected_mult then
            widget.Text(string.format("Multiple Selection:%s",self.cur_selected_type))
        else
            widget.Text(string.format("Single Selection:%s",self.cur_selected_type))
        end
        local color_cfg = self.cur_selected_mult and MultStateColor or SingleStateColor
        for i,name in ipairs(color_cfg[1]) do
            local color = color_cfg[name]
            windows.PushStyleColor(enum.StyleCol.Header,table.unpack(color))
            widget.Selectable(name,true,100)
            windows.PopStyleColor()
            if i ~= #(color_cfg[1]) then
                cursor.SameLine(0,10)
            end
        end
    end
    windows.EndChild()

end

local function default_open_treenode(str)
    return widget.TreeNode(str,flags.TreeNode.DefaultOpen)
end
function sorted_pairs(t)
    local a = {}

    for n in pairs(t) do
        a[#a + 1] = n
    end

    table.sort(a)

    local i = 0
        
    return function()
        i = i + 1
        return a[i], t[a[i]]
    end
end

function GuiPolicyComponentPair:policy_selectable(name,selected)
    assert(not (selected and self.pairs_map.policy))
    if selected then
        if widget.Selectable(name,selected) then
            self:on_select_item("policy",name)
        end
    else
        local policy = self.pairs_map.policy
        local state = policy and policy[name]
        if state then
            local color = SingleStateColor[state]
            windows.PushStyleColor(enum.StyleCol.Header,table.unpack(color))
        end
        if widget.Selectable(name,state and true or false) then
            self:on_select_item("policy",name)
        end
        if state then
            windows.PopStyleColor()
        end
    end
    if util.IsItemHovered() then
        widget.BeginTooltip()
        local policy_data = self.cache.policy_tbl[name]
        if policy_data.package then
            if default_open_treenode("Package") then
                widget.BulletText(policy_data.package)
                widget.TreePop()
            end
        end
        if policy_data.defined then
            if default_open_treenode("Location") then
                widget.BulletText(policy_data.defined)
                widget.TreePop()
            end
        end
        local transforms = policy_data.transforms
        if transforms and #transforms> 0 then
            if default_open_treenode("Transforms") then
                for i,trans in ipairs(transforms) do
                    if default_open_treenode(trans.name) then
                        if default_open_treenode("Input") then
                            for i,input in ipairs(trans.input) do
                                widget.BulletText(input)
                            end
                            widget.TreePop()
                        end
                        if default_open_treenode("Output") then
                            windows.PushStyleColor(enum.StyleCol.Text,1,0,0,1)
                            for i,output in ipairs(trans.output) do
                                widget.BulletText(output)
                            end
                            windows.PopStyleColor()
                            widget.TreePop()
                        end
                        widget.TreePop()
                    end
                end
                widget.TreePop()
            end
        end
        local components = policy_data.components
        if default_open_treenode("Component") then
            for cname,_ in sorted_pairs(components) do
                widget.BulletText(cname)
                if policy_data.is_unique[cname] then
                    cursor.SameLine()
                    widget.Text("[unique]")
                end
            end
            widget.TreePop()
        end
        local require_package = policy_data.require_package
        local require_system = policy_data.require_system
        local require_policy = policy_data.require_policy
        if require_package or require_system or require_policy then
            cursor.Separator()
        end
        if require_package and  default_open_treenode("RequirePackage") then
            for _,name in sorted_pairs(require_package) do
                widget.BulletText(name)
            end
            widget.TreePop()
        end
        if require_system and  default_open_treenode("RequireSystem") then
            for _,name in sorted_pairs(require_system) do
                widget.BulletText(name)
            end
            widget.TreePop()
        end
        if require_policy and  default_open_treenode("RequirePolicy") then
            for _,name in sorted_pairs(require_policy) do
                widget.BulletText(name)
            end
            widget.TreePop()
        end
        widget.EndTooltip()
    end
end

function GuiPolicyComponentPair:component_selectable(name,selected)
   assert(not (selected and self.pairs_map.component))
    if selected then
        if widget.Selectable(name,selected) then
            self:on_select_item("component",name)
        end
    else
        local component = self.pairs_map.component
        local state = component and component[name]
        if state then
            local color
            if self.cur_selected_mult then
                color = MultStateColor[state]
            else
                color = SingleStateColor[state]
            end
            windows.PushStyleColor(enum.StyleCol.Header,table.unpack(color))
        end
        if widget.Selectable(name,state and true or false) then
            self:on_select_item("component",name)
        end
        if state then
            windows.PopStyleColor()
        end
    end
    if util.IsItemHovered() then
        local component_data = self.cache.component_tbl[name]
        widget.BeginTooltip()
        if component_data then
            
            if  self.cur_selected_mult then
                assert(self.cur_selected_type == "policy")
                local component = self.pairs_map.component
                local state = component and component[name]
                if state == "conflict" then
                    windows.PushStyleColor(enum.StyleCol.Text,1,0,0,1)
                    if default_open_treenode("Conflict:") then
                        for pname,pstate in pairs(component_data) do
                            if pstate == "output" and self.selected_map["policy"][pname] then
                                widget.Text(pname)
                                local transforms = self.cache.policy_tbl[pname].transforms
                                for _,trans in pairs(transforms) do
                                    local clist = trans["output"]
                                    for _,cname in ipairs(clist) do
                                        if cname == name then
                                            local str = string.format("output of transform[%s]",trans.name)
                                            widget.BulletText(str)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        widget.TreePop()
                    end
                    windows.PopStyleColor()
                    cursor.Separator()
                end
            end
            if default_open_treenode("Using by policy:") then
                for policy_name,state in sorted_pairs(component_data) do
                    widget.Text(policy_name)
                    if state ~= "normal" then
                        local transforms = self.cache.policy_tbl[policy_name].transforms
                        assert(transforms)
                        for _,trans in pairs(transforms) do
                            local clist = trans[state]
                            for _,cname in ipairs(clist) do
                                if cname == name then
                                    local str = string.format("%s of transform[%s]",state,trans.name)
                                    widget.BulletText(str)
                                    break
                                end
                            end
                        end
                    end
                end
                widget.TreePop()
            end                                                
            
        else
            widget.Text("Not used by any policies")
        end              
        widget.EndTooltip()
    end
end

--typ:"policy"/"component"
function GuiPolicyComponentPair:on_select_item(typ,name)
    if self.cur_selected_type and self.cur_selected_type ~= typ then
        for k,_ in pairs(self.selected_map) do
            if k ~= typ then
                self.selected_map[k] = {}
            end
        end
    end
    self.cur_selected_type = typ
    local selected_map = self.selected_map[typ]
    if (typ == "policy")  and gui_input.key_state.CTRL then
        selected_map[name] = (not selected_map[name]) or nil
        if not next(selected_map) then
            self.cur_selected_type = nil
        end
    else
        self.selected_map[typ] = {[name] = true}
    end
    self:_refresh_pair()
end

function GuiPolicyComponentPair:on_select_all(typ)
    assert(typ == "policy")
    if self.cur_selected_type and self.cur_selected_type ~= typ then
        for k,_ in pairs(self.selected_map) do
            if k ~= typ then
                self.selected_map[k] = {}
            end
        end
    end
    self.cur_selected_type = typ
    local selected_map = self.selected_map[typ]
    local sorted_names = self.cache.sorted.policies
    for _,name in ipairs(sorted_names) do
        selected_map[name] = true
    end
    self:_refresh_pair()
end


function GuiPolicyComponentPair:_refresh_pair()
    if not self.cur_selected_type then
        self.pairs_map.policy = nil
        self.pairs_map.component = nil
        self.cur_selected_mult = false
    else
        if self.cur_selected_type == "policy" then
            local count = 0
            for k,v in pairs(self.selected_map.policy) do
                count = count + 1
                if count >=2 then
                    break
                end
            end
            local is_mult = (count >=2)
            self.cur_selected_mult = is_mult
            if not is_mult then -- single_select
                local select_policy = next(self.selected_map.policy)
                self.pairs_map.component = self.cache.policy_tbl[select_policy].components
            else --mult_select
                local has_been_output = {}
                local component_state = {}
                for pname,_ in pairs(self.selected_map.policy) do
                    local pdata = self.cache.policy_tbl[pname]
                    for cname,state in pairs(pdata.components) do
                        component_state[cname] = component_state[cname] or "normal" 
                        if state == "output" then
                            if has_been_output[cname] then
                                component_state[cname] = "conflict"
                            else
                                has_been_output[cname] = true
                            end
                        end 
                    end
                end
                self.pairs_map.component = component_state
            end
            self.pairs_map.policy = nil
        else --component
            local selected_component = next(self.selected_map["component"])
            self.pairs_map.policy = self.cache.component_tbl[selected_component]
            self.cur_selected_mult = false
            self.pairs_map.component = nil
        end
    end


end

return GuiPolicyComponentPair
