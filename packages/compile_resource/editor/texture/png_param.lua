
local function default_param(path)
    return {
        colorspace = "sRGB",
        compress = {
            android= "ASTC6x6",
            ios= "ASTC6x6",
            windows= "BC3",
        },
        normalmap= false,
        local_texpath = path,
        sampler={
          MAG= "LINEAR",
          MIN= "LINEAR",
          MIP= "LINEAR",
          U= "CLAMP",
          V= "CLAMP",
        },
        type = "texture",
    }

end

local function raw_param(path, format)
    return {
        colorspace = "sRGB",
        format = format,
        normalmap= false,
        local_texpath= path,
        sampler={
          MAG= "LINEAR",
          MIN= "LINEAR",
          MIP= "LINEAR",
          U= "CLAMP",
          V= "CLAMP",
        },
        type = "texture",
    }
end

local function default_sampler()
	return {
		U="WRAP",
		V="WRAP",
		W="WRAP",
		MIN="LINEAR",
		MAG="LINEAR",
		MIP="POINT",
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

return {
    default = default_param,
    raw     = raw_param,
    sampler = fill_default_sampler,
}