local texutil = require "editor.texture.util"

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
    local binfile = texutil.what_bin_file(output, setting.identity)
    local ok, err = texutil.convert_image(output, input, binfile, default_param(input))
    if not ok then
		return ok, err
	end
	return true, {input}
end