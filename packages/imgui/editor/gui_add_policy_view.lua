local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local IO = imgui.IO
local gui_input = require "gui_input"
local gui_util = require "editor.gui_util"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local GuiBase = require "gui_base"
local GuiAddPolicyView = GuiBase.derive("GuiAddPolicyView")
GuiAddPolicyView.GuiName = "GuiAddPolicyView"

local function pairs_by_sortkey(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

-- local 
function GuiAddPolicyView:_init()
    GuiBase._init(self)
    self.default_size = {350,450}
    self.title_id = string.format("AddPolicy###%s",self.GuiName)
    self.policy_tree = nil -- {package=[info,...]}
    self.filter_policy_tree = nil
    self.policy_selected = {}
    self._is_opened = false
    self.filter_text = {
        text = "",
        -- flags = flags.InputText { "CallbackCharFilter", "CallbackHistory", "CallbackCompletion" },
    }
    self:_init_subcribe()
end

function GuiAddPolicyView:_init_subcribe()
    hub.subscribe(Event.OpenAddPolicyView,self.open_add_policy_view,self)
end

function GuiAddPolicyView:_init_schema_info()
    if not self.policy_tree then
        local util = require "editor.gui_util"
        local schema_map = util.get_all_schema()
        local policies = schema_map.policies

        local policy_tree = {}
        for name,info in pairs(policies) do
            local pkg = info.package
            policy_tree[pkg] = policy_tree[pkg] or {}
            info.name = name
            table.insert(policy_tree[pkg],info)
        end
        for _,list in pairs(policy_tree) do
            table.sort(list,function(a,b)
                return a.name>b.name
            end)
        end
        self.policy_tree = policy_tree
        self.policy_info = policies
        log.info_a(policies)
        log.info_a(policy_tree)
    end
end

function GuiAddPolicyView:open_add_policy_view(eids,entity_info)
    self:on_open_click()
    log.info_a(eids,entity_info)
    assert(eids and eids[1] and entity_info[eids[1]] )
    self.target_eids = eids
    self.target_entity_infos = entity_info
end

function GuiAddPolicyView:update_filter()
    local filter_text = tostring(self.filter_text.text)
    if filter_text and filter_text ~="" then
        self.filter_policy_tree = nil
    end
    local filter_tree = {}
    for pkg,list in pairs(self.policy_tree) do
        if string.find(pkg,filter_text) then
            filter_tree[pkg] = list
        else
            local filter_list = nil
            for _,info in ipairs(list) do
                local pname = info.name
                if string.find(pname,filter_text) then
                    filter_list = filter_list or {}
                    table.insert(filter_list,info)
                end
            end
            if filter_list then
                filter_tree[pkg] = filter_list
            end
        end
    end
    self.filter_policy_tree = filter_tree
end

function GuiAddPolicyView:on_update()
    self:_init_schema_info()
    widget.Text("This is Add policy")
    widget.Text("Filter:")
    cursor.SameLine()
    if widget.InputText("###filter", self.filter_text) then
        log(self.filter_text.text)
        self:update_filter()
    end
    cursor.SameLine()
    if widget.Button("Clear") then
        self.filter_text.text = ""
        self:update_filter()
    end
    local PackageFlag = flags.TreeNode.OpenOnDoubleClick
    local PolicyFlag = flags.TreeNode.Leaf
    local policy_tree = self.filter_policy_tree or self.policy_tree
    for name,list in pairs_by_sortkey(policy_tree) do
        local open = widget.TreeNode(name,flag)
        if open then
            for _,info in ipairs(list) do
                local pname = info.name
                local flag = PolicyFlag
                if self.policy_selected[pname] then
                    flag = PolicyFlag | flags.TreeNode.Selected
                end
                if widget.TreeNode(pname,flag) then
                    widget.TreePop()
                end
                if util.IsItemClicked() then
                    if gui_input.key_state.CTRL then
                        self.policy_selected[pname] = (not self.policy_selected[pname]) or nil
                    else
                        self.policy_selected = {[pname] = true}
                    end
                end
            end
        end
        if open then
            widget.TreePop()
        end
    end
    if self.target_eids then
        widget.Text("Selected Entity:"..self.target_eids[1])
    end
    local has_selected =  next(self.policy_selected)
    if has_selected then
        if widget.Button("Add Policy") then
            log.info_a("Add policy:",self.target_eids,self.policy_selected)
            self:request_add_policy(self.target_eids,self.policy_selected)
        end
    end

end

function GuiAddPolicyView:request_add_policy(eids,policy_selected)
    local policies = {}
    for name,_ in pairs(policy_selected) do
        local pkg = self.policy_info[name].package
        table.insert(policies,pkg.."|"..name)
    end
    hub.publish(Event.RequestAddPolicy,eids,policies,{test_component = true})
end

function GuiAddPolicyView:after_close()
    self.target_eids = nil
    self.target_entity_infos = nil
    self.policy_selected = {}
end

return GuiAddPolicyView