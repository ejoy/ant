local ecs = ...
local world = ecs.world
local w = world.w

ecs.require "widget.material_view"
local prefab_mgr = ecs.require "prefab_manager"
local imgui     = require "imgui"
local utils     = require "common.utils"
local math3d    = require "math3d"
local uiproperty = require "widget.uiproperty"
local hierarchy     = require "hierarchy_edit"
local MaterialView = require "widget.view_class".MaterialView
local SkyboxView  = require "widget.view_class".SkyboxView
local size_str = {"16","32","64","128","256","512","1024"}
local prefilter_size_str = {"256","512","1024"}

local function set_ibl_value(eid, key, value)
    local sz = tonumber(value)
    local template = hierarchy:get_template(eid)
    template.template.data.ibl[key].size = sz
    world:entity(eid).ibl[key].size = sz
    prefab_mgr:save_prefab()
    prefab_mgr:reload()
end

function SkyboxView:_init()
    MaterialView._init(self)
    self.irradiance = uiproperty.Combo({label = "Irradiance", options = size_str},{
        getter = function ()
            return tostring(world:entity(self.eid).ibl.irradiance.size)
        end,
        setter = function (value)
            set_ibl_value(self.eid, "irradiance", value)
        end
    })
    self.prefilter  = uiproperty.Combo({label = "Prefilter", options = prefilter_size_str},{
        getter = function()
            return tostring(world:entity(self.eid).ibl.prefilter.size)
        end,
        setter = function()
            return tostring(world:entity(self.eid).ibl.LUT.size)
        end
    })
    self.LUT = uiproperty.Combo({label = "LUT", options = size_str},{
        getter = function ()
            return tostring(world:entity(self.eid).ibl.LUT.size)
        end,
        setter = function (value)
            set_ibl_value(self.eid, "LUT", value)
        end
    })
end

function SkyboxView:set_model(eid)
    if not MaterialView.set_model(self, eid) then return false end
    self:update()
    return true
end

function SkyboxView:update()
    MaterialView.update(self)
    self.irradiance:update()
    self.prefilter:update()
    self.LUT:update()
end

function SkyboxView:show()
    if not world:entity(self.eid) then return end
    MaterialView.show(self)
    self.irradiance:show()
    self.prefilter:show()
    self.LUT:show()
end

return SkyboxView