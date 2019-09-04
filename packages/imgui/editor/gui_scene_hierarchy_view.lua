local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local IO = imgui.IO
local gui_input = require "gui_input"

local GuiBase = require "gui_base"
local GuiHierarchyView = GuiBase.derive("GuiHierarchyView")
GuiHierarchyView.GuiName = "GuiHierarchyView"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local LeafFlag = flags.TreeNode.Leaf
local ParentFlag = flags.TreeNode.OpenOnDoubleClick

function GuiHierarchyView:_init()
    GuiBase._init(self)
    self.win_flags = flags.Window { "MenuBar" }
    self.hierarchy_data = {}
    self.sorted_map = {}
    self.default_size = {250,600}
    self.title_id = string.format("SceneHierarchy###%s",self.GuiName)
    self.selected_map = {}
    self._scroll_flag = false
    ---
    self:_init_subcribe()
end

-------hub begin
function GuiHierarchyView:_init_subcribe()
    hub.subscribe(Event.HierarchyChange,self._on_refresh_hierarchy,self)
    hub.subscribe(Event.EntityPick, self._on_scene_pick,self)
end

function GuiHierarchyView:publish_selected_entity(eid,focus)
    hub.publish(Event.WatchEntity, eid, focus)
end

function GuiHierarchyView:publish_operate_event(event,args)
    hub.publish(Event.EntityOperate, event, args)
end
-------hub end

function GuiHierarchyView:_on_scene_pick(eid_list)
    self.selected_map = {}
    for _,eid in ipairs(eid_list) do
        self.selected_map[eid] = true
        self._scroll_flag = true
    end
end

function GuiHierarchyView:_on_refresh_hierarchy(tbl)
    log.trace_a("_on_refresh_hierarchy",tbl)
    self.hierarchy_data = tbl
    self.sorted_map = {}
end

function GuiHierarchyView:on_update()
    self:_update_menu_bar()
    self:_render_children(self.hierarchy_data)
end

function GuiHierarchyView:_update_menu_bar()
    if widget.BeginMenuBar() then
        if widget.MenuItem("Sync") then
            hub.publish(Event.RequestHierarchy)
        end
        widget.EndMenuBar()
    end
end

function GuiHierarchyView:_render_children(children)
    local sorted = self.sorted_map[children]
    if not sorted then
        local cache = {}
        for id,_ in pairs(children) do
            table.insert(cache,id)
        end
        table.sort(cache)
        self.sorted_map[children] = cache
        sorted = cache
    end
    for _,id in ipairs(sorted) do
        self:_render_entity(id,children[id])
    end
end

function GuiHierarchyView:_render_entity(id,entity)
    local children = entity.children
    local flag = ParentFlag
    if not children then
        flag = LeafFlag
    end
    local name = string.format("[%d]%s",id,entity.name)
    if self.selected_map[id] then
        flag = flag | flags.TreeNode.Selected
    end
    if entity.childnum >= 1 and entity.childnum <= 9 then
        widget.SetNextItemOpen(true,"f")
    end
    local cur_open = widget.TreeNode(name,flag)
    if self._scroll_flag and self.selected_map[id] then
        windows.SetScrollHereY()
        self._scroll_flag = false
    end
    self:_show_selected_entity_menu(id,entity)

    if util.IsItemClicked() then
        if gui_input.key_state.CTRL then
            self.selected_map[id]=true
        else
            self.selected_map = {[id]=true}
        end
        self:publish_selected_entity(id,util.IsMouseDoubleClicked(0))
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
        if children then
            self:_render_children(children)
        end
        widget.TreePop()
    end
end

function GuiHierarchyView:_show_selected_entity_menu(id,entity)
    local open = windows.BeginPopupContextItem("Selected_Menu###"..id,1)
    if open then
        if widget.Button("Select children") then
            local select_children = nil
            select_children = function(children)
                for i,c in pairs(children) do
                    self.selected_map[i]=true
                    if c.children then
                        select_children(c.children)
                    end
                end
            end
            self.selected_map[id]=true
            if entity.children then
                select_children(entity.children)
            end
        end
        if widget.Button("Delete") then
            local id_list = {}
            for id,_ in pairs(self.selected_map) do
                table.insert(id_list,id)
            end
            self:publish_operate_event( "Delete",id_list )
        end
        windows.EndPopup()
    end
    return open
end

return GuiHierarchyView