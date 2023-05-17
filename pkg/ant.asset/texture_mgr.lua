local textureman = require "textureman.client"
local async = require "async"
local DefaultTexture

local textures = {}

local function init()
	DefaultTexture = async.texture_default()
end

local mt = {}

function mt:__index(id)
    return textureman.texture_get(id)
end

setmetatable(textures, mt)

local function invalid(id)
	local tid = textureman.texture_get(id)
	return tid == DefaultTexture.TEX2D or tid == DefaultTexture.TEXCUBE
end

local function destroy(res)
	--TODO
end

local function default_textureid(t)
	t = t or "TEX2D"
	return assert(DefaultTexture[t], ("Invalid default texture type:%s"):format(t))
end

return {
	init = init,
	invalid = invalid,
	create = async.texture_create,
	destroy = destroy,
	default_textureid = default_textureid,
	textures = textures,
}
