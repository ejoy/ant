local ecs = ...
local world = ecs.world

local arena = require "arena"
local core = world:clibs "render.material.core"

local M = {}

local material_init_sys = ecs.system "material_init_system"
function material_init_sys:preinit()
    M.create_instance       = core.instance(arena._name)
    M.system_attrib_update  = core.system_attrib_update(arena._system, arena._arena)
    M.clear_all_uniforms    = function ()
        core.clear_all_uniforms(arena._arena)
    end
end

return M
