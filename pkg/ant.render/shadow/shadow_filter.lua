local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"

local setting	= import_package "ant.settings"

local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"
if not ENABLE_SHADOW then
    return
end

local FILTER_MODE<const>			= setting:get "graphic/shadow/filter_mode"
local SHADOW_FILTER_PARAM = math3d.ref()
if FILTER_MODE == "esm" then
	SHADOW_FILTER_PARAM.v = math3d.vector(0.0, 0.0, 0.0, 1.0)
end

pcf					= {
    fix4			= setting:get "graphic/shadow/pcf/fix4",
    kernelsize		= setting:get "graphic/shadow/pcf/kernelsize",
}

local sf_sys = ecs.system "shadow_filter_system"

--[[

]]



function sf_sys:init()
    local sfp = shadowcfg.shadow_filter_param()
    if sfp then
        imaterial.system_attrib_update("u_shadow_filter_param", sfp)
    end
end



return isf