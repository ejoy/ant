local assetmgr 	= require "asset"
local bgfx		= require "bgfx"
local math3d 	= require "math3d"

local function load_fx(fx)
	return assetmgr.load(fx)
end

local function load_state(state)
	return bgfx.make_state(type(state) == "string" and
		assetmgr.load(state)._data or
		state)
end

local function uniformdata_init(v)
	local num = #v
	if num == 4 then
		return math3d.ref(math3d.vector(v))
	elseif num == 16 then
		return math3d.ref(math3d.matrix(v))
	elseif num == 0 then
		return math3d.ref()
	else
		error(string.format("invalid uniform data, only support 4/16 as vector/matrix:%d", num))
	end
end

local function load_uniform(uniform)
	for i=1, #uniform do
		uniform[i] = uniformdata_init(uniform[i])
	end
	return uniform
end

local function load_texture(tex)
	tex.texture = assetmgr.load(tex.texture)
	tex.handle = tex.texture.handle
end

local function load_properties(properties)
	if properties then
		local textures = properties.textures
		if textures then
			for _, tex in pairs(textures) do
				load_texture(tex)
			end
		end
		local uniforms = properties.uniforms
		if uniforms then
			for _, uniform in pairs(uniforms) do
				load_uniform(uniform)
			end
		end
	end
	return properties
end

local function refine_properties(properties)
	if properties then
		local uniforms = properties.uniforms
		if uniforms then
			for _, u in pairs(uniforms) do
				local vl = u.value
				table.move(vl, 1, #vl, 1, u)
				u.value = nil
			end
		end
	end

	return properties
end

local function loader(filename, data)
	local res      = data or assetmgr.load_depiction(filename)
	res.fx         = load_fx(res.fx, data)
	res.state      = load_state(res.state)
	res.properties = load_properties(refine_properties(res.properties))
	return res
end

local function unloader(res)
	bgfx.destroy(res.fx.shader.prog)
	res.fx 			= nil
	res.state 		= nil
	res.properties 	= nil
end

return {
	loader = loader,
	unloader = unloader,

	load_properties = load_properties,
	load_uniform = load_uniform,
}
