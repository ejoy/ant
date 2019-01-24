local bgfx = require "bgfx"
local fs = require "filesystem"
local assetmgr = require "asset"
local rawtable = require "rawtable"

local function texture_load(filepath, info)
	local filename = filepath:string()
	local f = assert(io.open(filename, "rb"))
	local imgdata = f:read "a"
	f:close()
	local h = bgfx.create_texture(imgdata, info)
	bgfx.set_name(h, filename)
	return h
end

local function generate_sampler_flag(sampler)
	if sampler == nil then
		return nil
	end
	local flag = ""	
	local sample_types = {U="u", V="v", W="w", MIN="-", MAG="+", MIP="*"}

	local sample_value = {
		CLAMP="c", BORDER="b", MIRROR="",	--default
		POINT="p", ANISOTROPIC="a", LINEAR="", --default,
	}	

	for k, v in pairs(sampler) do
		local value = sample_value[v]
		if value == nil then
			error("not support data, sample value : %s", v)
		end

		if #value ~= 0 then
			local type = sample_types[k]
			if type == nil then
				error("not support data, sample type : %s", k)
			end
			
			flag = flag .. type .. value
		end
	end

	return flag

end

local function default_sampler()
	return {
		U="MIRROR",
		V="MIRROR",
		W="MIRROR",
		MIN="LINEAR",
		MAG="LINEAR",
		MIP="LINEAR",
	}
end

local function fill_default_sampler(sampler)
	local d = default_sampler()
	if sampler == nil then
		return d
	end

	for k, v in pairs(d) do
		if sampler[k] == nil then
			sampler[k] = v
		end
	end

	return sampler
end

return function (pkgname, respath)
	local tex = rawtable(assetmgr.find_depiction_path(pkgname, respath))
	local texrefpath = tex.path
	local tpkgname, trespath = texrefpath[1], fs.path(texrefpath[2])
	local pp = assetmgr.find_asset_path(tpkgname, trespath)
	if pp == nil then
		error(string.format("texture path not found, .texture path:[%s:%s], texture file:[%s:%s]", 
			pkgname, respath, tpkgname, trespath))
	end

	local sampler = tex.sampler
	local flag = generate_sampler_flag(sampler)
	
	local handle = texture_load(pp, flag)
	return {handle=handle, sampler=fill_default_sampler(sampler), path=texrefpath}
end