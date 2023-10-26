local sample_types = {
	U="u", V="v", W="w",
	MIN="-", MAG="+", MIP="*",
	COMPARE="c",
	BOARD_COLOR="c",
	RT = "r",
	COLOR_SPACE="S",
	BLIT = "b",
	SAMPLE = "s",
}

local sample_value = {
	-- filter mode
	CLAMP="c", MIRROR = "m", BORDER="b", WRAP="w",	--default
	-- filter address
	POINT="p", ANISOTROPIC="a", LINEAR="l", --default,

	-- color space
	sRGB="g",
	--LINEAR="l",

	-- compare
	COMPARE_LESS = '<',
	COMPARE_LEQUAL = '[',
	COMPARE_EQUAL = '=',
	COMPARE_GEQUAL = ']',
	COMPARE_GREATER = '>',
	COMPARE_NOTEQUAL = '!',
	COMPARE_NEVER = '-',
	COMPARE_ALWAYS = '+',

	-- RT
	RT_ON	='t',
	RT_MSAA_SAMPLE='s',
	RT_READ	="", RT_WRITE="w",
	RT_MSAA2="2", RT_MSAA4="4", RT_MSAA8="8", RT_MSAAX="x",

	-- BLIT
	BLIT_AS_DST			= 'w',
	BLIT_READBACK_ON	= 'r',
	BLIT_COMPUTEREAD	= '',
	BLIT_COMPUTEWRITE	= 'c',

	--SAMPLE
	SAMPLE_STENCIL='s', SAMPLE_DEPTH='d',
}

return function (sampler)
	local flag = {}
	local function add_cfg(k, v)
		flag[#flag+1] = k
		flag[#flag+1] = v
	end
	for k, v in pairs(sampler) do
		local t = sample_types[k] or error (("Invalid sample type:%s"):format(k))
		if k == "BOARD_COLOR" then
			add_cfg(t, v)
		else
			for it in v:gmatch "[^|]+" do
				local value = sample_value[it]
				if value == nil then
					error("not support data, sample value : %s", it)
				end
				add_cfg(t, value)
			end
		end
	end

	return table.concat(flag, "")
end