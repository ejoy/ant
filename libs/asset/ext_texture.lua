-- luacheck: globals import
local require = import and import(...) or require

local rawtable = require "rawtable"
local bgfx = require "bgfx"

local assetmgr = require "asset"
local vfs_fs = require "vfs.fs"

local function texture_load(filename, info)
	local f = assert(vfs_fs.open(filename, "rb"))
	if f == nil then
		error(string.format("load texture file failed, filename : %s", filename))
	end
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

	for k, v in pairs(sampler) do
		if v == nil then
			sampler[k] = d[k]
		end
	end

	return sampler
end

return function (filename)
	local fn = assetmgr.find_depiction_path(filename)
	local tex = rawtable(fn)

	local pp = assetmgr.find_valid_asset_path(assert(tex.path))
	if pp == nil then
		error("texture path is not valid, path is : " .. tex.path)
	end

	local sampler = tex.sampler

	local flag = generate_sampler_flag(sampler)
	
	local handle = texture_load(pp, flag)
	return {handle=handle, sampler=fill_default_sampler(sampler), path=tex.path}
end