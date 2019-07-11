local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local IO = imgui.IO

local GuiBase = require "gui_base"
local GuiHierarchyView = GuiBase.derive("GuiHierarchyView")
GuiHierarchyView.GuiName = "GuiHierarchyView"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local LeafFlag = flags.TreeNode.Leaf
local ParentFlag = flags.TreeNode.OpenOnDoubleClick

function GuiHierarchyView:_init()
    GuiBase._init(self)
    self.hierarchy_data = {}
    self.sorted_map = {}
    self.default_size = {250,600}
    self.title_id = string.format("SceneHierarchy###%s",self.GuiName)
    ---
    self:_init_subcribe()
end

-------hub begin
function GuiHierarchyView:_init_subcribe()
    hub.subscribe(Event.HierarchyChange,self._on_refresh_hierarchy,self)
end

function GuiHierarchyView:publish_selected_entity(eid)
    hub.publish(Event.WatchEntity, eid)
end
-------hub end

function GuiHierarchyView:_on_refresh_hierarchy(tbl)
    log.info_a("_on_refresh_hierarchy",tbl)
    self.hierarchy_data = tbl
    self.sorted_map = {}
end

function GuiHierarchyView:on_update()
    self:_render_children(self.hierarchy_data)
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
    local flags = ParentFlag
    if not children then
        flags = LeafFlag
    end
    local name = string.format("[%s]%s",tostring(id),entity.name)
    local cur_open = widget.TreeNode(name,flags)
    if util.IsItemClicked() then
        self:publish_selected_entity(id)
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

return GuiHierarchyView