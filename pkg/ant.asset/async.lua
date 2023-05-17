local ltask = require "ltask"
local ServiceResource

local m = {}

function m.init()
    ServiceResource = ltask.uniqueservice "ant.compile_resource|resource"
end

function m.shader_create(filename)
    return ltask.call(ServiceResource, "shader_create", filename)
end

function m.texture_create(filename)
	return ltask.call(ServiceResource, "texture_create", filename)
end

function m.texture_default()
	return ltask.call(ServiceResource, "texture_default")
end

return m