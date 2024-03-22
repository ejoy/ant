local ecs   = ...
local world = ecs.world
local w     = world.w

local mc        = import_package "ant.math".constant
local math3d    = require "math3d"

local setting	= import_package "ant.settings"

local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"
if not ENABLE_SHADOW then
    return
end

local FILTER_MODE<const>			= setting:get "graphic/shadow/filter_mode"
local filter_modes = {
    pcf   = {
        gen_param   = function (self)
            return mc.ZERO
        end,
    },
    evsm = {
        gen_param   = function ()
            return mc.ZERO
        end,
    }
}

local imaterial = ecs.require "ant.render|material"

local sf_sys = ecs.system "shadow_filter_system"

function sf_sys:init()
    imaterial.system_attrib_update("u_shadow_filter_param", filter_modes[FILTER_MODE]:gen_param())
end
