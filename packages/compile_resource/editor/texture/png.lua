local convert_image = require "editor.texture.util"

local function default_param(path)
    return {
        colorspace = "sRGB",
        compress = {
            android= "ASTC6x6",
            ios= "ASTC6x6",
            windows= "BC3",
        },
        normalmap= false,
        path= path,
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

return function (input, output, setting)
    local p = default_param()
    p.setting = setting
    p.local_texpath = input
    local ok, err = convert_image(output, p)
    if not ok then
		return ok, err
	end
	return true, {input}
end
