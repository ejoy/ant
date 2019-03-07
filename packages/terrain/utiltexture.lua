local bgfx = require "bgfx"
local assetmgr = import_package "ant.asset"
local fs = require "filesystem"

local function texture_load(filename, info)
	local f = assert(fs.open(fs.path(filename), "rb"))
	local imgdata = f:read "a"
	f:close()
	print("   image name = "..filename)
	print("   image size = "..#imgdata)
	local h = bgfx.create_texture(imgdata, info or "ucvc-p+a" )
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
	--local assetmgr = import_package "ant.asset"
	--local tex = rawtable(filename)
	--local pp = assetmgr.find_asset_path(nil, fs.path(assert(filename)))
	if pp == nil then
		error("texture path is not valid, path is : ", -1)
	end

	local sampler = {
        U = "MIRROR",
        V = "MIRROR",
        MIN = "LINEAR",
        MAG = "LINEAR",	
	}
	
	local flag = generate_sampler_flag( sampler )

	local handle = texture_load( filename, flag or "umvm-p+a*p" )
	
	return { handle=handle, sampler = fill_default_sampler(sampler), }
end
