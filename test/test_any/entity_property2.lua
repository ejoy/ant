local log = log and log(...) or print

require "iupluacontrols"

local iupcontrols   = import_package "ant.iupcontrols"
local editor = import_package "ant.editor"
local math = import_package "ant.math"
local ms = math.stack
local su = import_package "ant.serialize"

local property_builder = require "entity_property_builder"

local entity_property = {}

function entity_property:build(entity)
    if self._container then
        iup.Detach(self._container)
        iup.Destroy(self._container)
        self._container = nil
    end

    local container = iup.vbox({})
    container.expand = "YES"
    container.ncmargin = "8x8"
    iup.Append(self.scrollbox,container)
    self._container = container
    local world = self.editor_window:get_editor_world()
    property_builder.build_enity(container,entity,world._schema.map)
    iup.Map(container)
    iup.Refresh(container)
end

function entity_property:on_focus_entity(serialize)
    local world = self.editor_window:get_editor_world()
    local eid = world:find_serialize(serialize)
    local entity = world[eid]
    self:build(entity)
end

function entity_property:get_view()
    return self.view
end

function entity_property.new(config,editor_window)
    local ins = setmetatable({},{__index = entity_property })
    -- ins._container = iup.vbox({})
    ins.view = iup.frame(config.view)
    ins.view.title = "Properties"
    ins.view.expand = "YES"
    ins.scrollbox = iup.scrollbox {}
    iup.Append(ins.view,ins.scrollbox)
    ins.editor_window = editor_window
    local entity_property_hub = require "entity_property_hub"
    entity_property_hub.subscibe(ins)
    return ins
end

return entity_property