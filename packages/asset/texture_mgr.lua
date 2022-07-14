local ltask = require "ltask"
local ServiceResource = ltask.uniqueservice "ant.compile_resource|resource"
local DefaultTexture <const> = ltask.call(ServiceResource, "texture_default")

local textures = {}

local mt = {}

function mt:__index(id)
    ltask.fork(function()
        local res = ltask.call(ServiceResource, "texture_reload", id)
        if res then
            textures[res.id] = res.handle
        end
    end)
    return DefaultTexture
end

setmetatable(textures, mt)

local function create(filename)
	local res = ltask.call(ServiceResource, "texture_create", filename)
	if res.uncomplete then
		--ltask.fork(function()
			local ok, handle = pcall(ltask.call, ServiceResource, "texture_complete", res.name)
			if ok then
				res.handle = handle
				res.uncomplete = nil
				textures[res.id] = res.handle
			end
		--end)
	else
		textures[res.id] = res.handle
	end
	return res
end

local function destroy(res)
	res.handle = ltask.call(ServiceResource, "texture_destroy", res.name)
	res.uncomplete = true
	textures[res.id] = nil
end

return {
    create = create,
    destroy = destroy,
    textures = textures,
}
