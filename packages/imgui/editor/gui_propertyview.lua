local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local IO = imgui.IO

local GuiBase = require "gui_base"
local GuiPropertyView = GuiBase.derive("GuiPropertyView")
GuiPropertyView.GuiName = "GuiPropertyView"

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local LeafFlag = flags.TreeNode.Leaf
local ParentFlag = 0

function GuiPropertyView:_init()
    GuiBase._init(self)
    self.hierarchy_data = {}
    self.sorted_map = {}
    self.default_size = {250,600}
    ---
    self:_init_subcribe()
end

function GuiPropertyView:_init_subcribe()
    hub.subscribe(Event.HierarchyChange,self._on_refresh_hierarchy,self)
end

function GuiPropertyView:_on_refresh_hierarchy(tbl)
    print_a("_on_refresh_hierarchy",tbl)
    self.hierarchy_data = tbl
    self.sorted_map = {}
end

function GuiPropertyView:on_update()
    self:_render_children(self.hierarchy_data)
end

function GuiPropertyView:_render_children(children)
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

function GuiPropertyView:_render_entity(id,entity)
    local children = entity.children
    local flags = 0
    if not children then
        flags = LeafFlag
    end
    local name = string.format("[%s]%s",tostring(id),entity.name)
    local cur_open = widget.TreeNode(name,flags)
    if cur_open then
        if children then
            self:_render_children(children)
        end
        widget.TreePop()
    end
end

return GuiPropertyView