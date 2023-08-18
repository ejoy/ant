local ecs = ...

local arena = require "arena"
local core = ecs.clibs "render.material.core"

local M = {}

local create_instance = core.instance(M._name)
function M.create_instance(name)
	local m = assert(arena.material[name])
	return create_instance(m)
end

M.system_attrib_update = core.system_attrib_update(M._system, M._arena)

return M
