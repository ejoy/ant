local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local IO = imgui.IO
local gui_input = require "gui_input"
local gui_mgr = require "gui_mgr"
local FastTree = require "controls.fast_tree"

local GuiBase = require "gui_base"
local GuiHierarchyView = GuiBase.derive("GuiHierarchyView")
GuiHierarchyView.GuiName = "GuiHierarchyView"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local rxbus = import_package("ant.rxlua").RxBus

local LeafFlag = flags.TreeNode.Leaf 
local ParentFlag = flags.TreeNode.OpenOnDoubleClick

local OrderedMap = require "common.ordered_map"

function GuiHierarchyView:_init()
    GuiBase._init(self)
    self.win_flags = flags.Window { "MenuBar" }
    self.hierarchy_data = {}
    self.sorted_map = {}
    self.default_size = {250,600}
    self.title_id = string.format("SceneHierarchy###%s",self.GuiName)
    self.selected_map = OrderedMap:new()
    self._scroll_flag = false
    self.fast_tree = FastTree.new()
    self.fast_tree:set_update_item_func(self._render_tree_node,self)
    self.tree_open_state = {}
    ---
    self:_init_subcribe()
end

-------hub begin
function GuiHierarchyView:_init_subcribe()
    hub.subscribe(Event.RTE.HierarchyChange,self._on_refresh_hierarchy,self)
    hub.subscribe(Event.RTE.SceneEntityPick, self._on_scene_pick,self)
end

function GuiHierarchyView:publish_selected_entity(eids,focus)
    log.info_a("publish_selected_entity:",eids,focus)
    local subject = rxbus:get_subject(Event.ETR.WatchEntity)
    subject:onNext(eids,focus)
    -- hub.publish(Event.ETR.WatchEntity, eid, focus)
end

function GuiHierarchyView:publish_operate_event(event,args)
    hub.publish(Event.ETR.EntityOperate, event, args)
end
-------hub end

function GuiHierarchyView:_on_scene_pick(eid_list)
    self.selected_map:removeAll()
    for _,eid in ipairs(eid_list) do
        self.selected_map:insert(eid)
        self._scroll_flag = true
    end
end

function GuiHierarchyView:_on_refresh_hierarchy(tbl)
    log.trace_a("_on_refresh_hierarchy",tbl)
    self.hierarchy_data = tbl
    self.sorted_map = {}
    self:transform_hierarchy_data(tbl)
    assert(self.root_node)
    self.fast_tree:set_tree_data(self.root_node,self.tree_open_state)
end

function GuiHierarchyView:transform_hierarchy_data(tbl)
    self.root_node = {
        key = -1,
        data = {
            eid = -1,
            name = "Scene"
        }
    }
    local tree_open_state = self.tree_open_state
    local function transform_r( node,tbl )
        local sorted_ids = {}
        for eid,_ in pairs(tbl) do
            table.insert(sorted_ids,eid)
        end
        if #sorted_ids > 0 then
            node.children = node.children or {}
            table.sort(sorted_ids)
            for i,eid in ipairs(sorted_ids) do
                local data = tbl[eid]
                local child_node = {
                    key = eid,
                    data = {
                        eid = eid,
                        name = data.name,
                        childnum = data.childnum
                    }
                }
                if tree_open_state[child_node.key] == nil then
                    if data.childnum > 10 then
                        tree_open_state[child_node.key] = false
                    end 
                end
                table.insert(node.children,child_node)
                if data.childnum > 0 then
                    transform_r(child_node,data.children)
                end
            end

        end
    end
    transform_r(self.root_node,tbl)
    self.root_node.data.childnum = #(self.root_node.children)
end

function GuiHierarchyView:on_update()
    self:_update_menu_bar()
    if not self.hierarchy_data then
        return 
    end
    self.fast_tree:update()

    -- if widget.TreeNode("Scene",flags.TreeNode.DefaultOpen) then
    --     self:_render_children(self.hierarchy_data)
    --     widget.TreePop()
    -- end
    self.context_menu_opened = false
    if not self.context_menu_opened and windows.BeginPopupContextWindow() then
        if widget.MenuItem("New Entity") then
            gui_mgr.getMgr("EntityMgr"):request_new_entity()
        end
        if widget.MenuItem("Duplicate Entity") then
            local eids = self.selected_map:get_list()
            gui_mgr.getMgr("EntityMgr"):request_duplicate_entity(eids)
        end
        windows.EndPopup() 
    end
end

function GuiHierarchyView:_update_menu_bar()
    if widget.BeginMenuBar() then
        if widget.MenuItem("Sync") then
            hub.publish(Event.ETR.RequestHierarchy)
        end
        widget.EndMenuBar()
    end
end

function GuiHierarchyView:_render_tree_node(node,opened)

    local entity = node.data
    local id = entity.eid
    local flag = ParentFlag
    if id <= 0 then
        local new_opened =  widget.TreeNode("Scene",flag)
        if new_opened then
            widget.TreePop()
        end
        return new_opened
    else
        if entity.childnum <= 0  then
            flag = LeafFlag
        end
        local name = string.format("[%d]%s",id,entity.name)
        if self.selected_map:has(id) then
            flag = flag | flags.TreeNode.Selected
        end
        widget.SetNextItemOpen(opened)
        -- if entity.childnum >= 1 and entity.childnum <= 9 then
        --     widget.SetNextItemOpen(true,"f")
        -- end
        local cur_open = widget.TreeNode(name,flag)
        if self._scroll_flag and self.selected_map:has(id) then
            windows.SetScrollHereY()
            self._scroll_flag = false
        end

        if util.IsItemClicked(0) and gui_input.key_state.CTRL then
            self.selected_map:insert(id)
            self:publish_selected_entity(self.selected_map:get_list(),util.IsMouseDoubleClicked(0))
        elseif util.IsItemClicked(0) or util.IsItemClicked(1) then
            self.selected_map:removeAll()
            self.selected_map:insert(id)
            self:publish_selected_entity(self.selected_map:get_list(),util.IsMouseDoubleClicked(0))
        end

        if not self.context_menu_opened then
            self.context_menu_opene = self:_show_selected_entity_menu(id,entity)
        end

        if util.IsItemHovered() then
            widget.BeginTooltip()
            widget.Text("Detail")
            cursor.Separator()
            widget.BulletText(string.format("EntityID:%d",id));
            widget.BulletText("...")
            widget.EndTooltip()
        end

        if cur_open then
            widget.TreePop()
        end
        return cur_open
    end
end

function GuiHierarchyView:_show_selected_entity_menu(id,entity)
    local open = windows.BeginPopupContextItem("Selected_Menu###"..id,1)
    if open then
        widget.Text(string.format("Entity:%d",id))
        if widget.Button("Select children") then
            local select_children = nil
            select_children = function(children)
                for i,c in pairs(children) do
                    self.selected_map:insert(i)
                    if c.children then
                        select_children(c.children)
                    end
                end
            end
            self.selected_map:insert(id)
            if entity.children then
                select_children(entity.children)
            end
        end
        if widget.Button("Delete") then
            self:publish_operate_event( "Delete",self.selected_map:get_list() )
        end
        windows.EndPopup()
    end
    return open
end

return GuiHierarchyView