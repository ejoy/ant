local ltask = require "ltask"
local textureman = require "textureman.client"
local ServiceResource
local DefaultTexture

local textures = {}

local function init()
	ServiceResource = ltask.uniqueservice "ant.compile_resource|resource"
	DefaultTexture = ltask.call(ServiceResource, "texture_default")
end

local mt = {}

function mt:__index(id)
    return textureman.texture_get(id)
end

setmetatable(textures, mt)

local function invalid(id)
	return textureman.texture_get(id) == DefaultTexture
end

local function create(filename)
	return ltask.call(ServiceResource, "texture_create", filename)
end

local function destroy(res)
	--TODO
end

return {
	init = init,
	invalid = invalid,
    create = create,
    destroy = destroy,
    textures = textures,
}
