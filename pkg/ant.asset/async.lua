local ltask = require "ltask"
local ServiceResource

local PM = require "programan.client"

local m = {}

function m.init()
    ServiceResource = ltask.uniqueservice "ant.resource_manager|resource"
end

function m.material_create(filename)
    return ltask.call(ServiceResource, "material_create", filename)
end

function m.material_destroy(filename)
    return ltask.call(ServiceResource, "material_destroy", filename)
end

function m.material_check()
	return ltask.call(ServiceResource, "material_check")
end

function m.material_mark(pid)
	return ltask.call(ServiceResource, "material_mark", pid)
end

function m.material_unmark(pid)
	return ltask.call(ServiceResource, "material_unmark", pid)
end

function m.material_isvalid(pid)
	local h = PM.program_get(pid)
	return (0xffff&h) ~= 0xffff
end

function m.texture_create(filename)
	return ltask.call(ServiceResource, "texture_create", filename)
end

function m.texture_create_fast(filename)
	return ltask.call(ServiceResource, "texture_create_fast", filename)
end

function m.texture_reload(filename)
	return ltask.call(ServiceResource, "texture_reload", filename)
end

function m.texture_default()
	return ltask.call(ServiceResource, "texture_default")
end

return m