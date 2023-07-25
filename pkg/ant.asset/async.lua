local ltask = require "ltask"
local ServiceResource

local m = {}

function m.init()
    ServiceResource = ltask.uniqueservice "ant.compile_resource|resource"
end

function m.material_create(filename)
    return ltask.call(ServiceResource, "material_create", filename)
end

function m.material_destroy(filename)
    return ltask.call(ServiceResource, "material_destroy", filename)
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

function m.compile(path)
	return ltask.call(ServiceResource, "compile", path)
end

return m