local ecs = ...
local world = ecs.world
local w = world.w

local uiproperty = require "widget.uiproperty"
local hierarchy     = require "hierarchy_edit"
local size_str = {"16","32","64","128","256","512","1024"}
local prefilter_size_str = {"256","512","1024"}

local iibl = ecs.require "ant.render|ibl.ibl"

local function template_data(eid, comp)
    local info = hierarchy:get_node_info(eid)
    return info.template.data[comp]
end

local function iblT(eid)
    return template_data(eid, "ibl")
end

local function set_ibl_value(eid, key, value)
    local sz = tonumber(value)
    local ibl = iblT(eid)
    ibl[key].size = sz
    local e <close> = world:entity(eid, "ibl:in")
    e.ibl[key].size = sz
    -- prefab_mgr:save_prefab()
    -- prefab_mgr:reload()
end
local SkyboxView = {}
function SkyboxView:_init()
    if self.inited then
        return
    end
    self.inited = true
    self.skybox = uiproperty.Group({label="Skybox"},{
        uiproperty.Float({label="FaceSize", min=0, speed=1, max=250000}, {
            getter = function ()
                local e <close> = world:entity(self.eid, "skybox:in")
                return e.skybox.facesize
            end,
            setter = function (value)
                template_data(self.eid, "skybox").facesize = value
                local e <close> = world:entity(self.eid)
                e.skybox.facesize = value
                -- prefab_mgr:save_prefab()
                -- prefab_mgr:reload()
            end
        })
    })
    self.IBL = uiproperty.Group({label="IBL"},{
        uiproperty.Float({label = "Intensity", min=0, speed=1, max=250000}, {
            getter = function ()
                local e <close> = world:entity(self.eid, "ibl:in")
                return e.ibl.intensity
            end,
            setter = function (value)
                local ibl_t = iblT(self.eid)
                ibl_t.intensity = value
                local e <close> = world:entity(self.eid, "ibl:in")
                e.ibl.intensity = value
                iibl.set_ibl_intensity(value)
                -- prefab_mgr:save_prefab()
                -- prefab_mgr:reload()
            end,
        }),
        uiproperty.Combo({label = "Irradiance", options = size_str},{
            getter = function ()
                local e <close> = world:entity(self.eid, "ibl:in")
                return tostring(e.ibl.irradiance.size)
            end,
            setter = function (value)
                set_ibl_value(self.eid, "irradiance", value)
            end
        }),
        uiproperty.Combo({label = "Prefilter", options = prefilter_size_str},{
            getter = function()
                local e <close> = world:entity(self.eid, "ibl:in")
                return tostring(e.ibl.prefilter.size)
            end,
            setter = function()
                local e <close> = world:entity(self.eid, "ibl:in")
                return tostring(e.ibl.LUT.size)
            end
        }),
        uiproperty.Combo({label = "LUT", options = size_str},{
            getter = function ()
                local e <close> = world:entity(self.eid, "ibl:in")
                return tostring(e.ibl.LUT.size)
            end,
            setter = function (value)
                set_ibl_value(self.eid, "LUT", value)
            end
        })
    })
end

function SkyboxView:set_eid(eid)
    if self.eid == eid then
        return
    end
    if not eid then
        self.eid = nil
        return
    end
    local e <close> = world:entity(eid, "skybox?in ibl?in")
    if not e.skybox and not e.ibl then
        self.eid = nil
        return
    end
    self.eid = eid
    self:update()
end

function SkyboxView:update()
    if not self.eid then
        return
    end
    local e <close> = world:entity(self.eid, "skybox?in ibl?in")
    if e.ibl then
        self.IBL:update()
    end
    if e.skybox then
        self.skybox:update()
    end
end

function SkyboxView:show()
    if not self.eid then
        return
    end
    local e <close> = world:entity(self.eid, "skybox?in ibl?in")
    if e.ibl then
        self.IBL:show()
    end
    if e.skybox then
        self.skybox:show()
    end
end

return function ()
    SkyboxView:_init()
    return SkyboxView
end