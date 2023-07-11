local convert_image = require "editor.texture.util"
local config        = require "editor.config"

return function (content, output, localpath)
	if content.path then
		content.local_texpath = localpath(assert(content.path))
	else
		assert(content.value, "memory texture should define the texture memory")
	
		if content.format ~= "RGBA8" then
			error(("memory texture only support format RGBA8, format:%s provided"):format(content.format))
		end
		
		local s = content.size
		local w,h = s[1], s[2]
		local numlayers = content.numLayers or 1
		if numlayers*w*h*4 ~= #content.value then
			error(("invalid image size [w, h]=[%d, %d], numLayers=%d, format:%s, value count:%d"):format(w, h, content.numLayers, content.format, #content.value))
		end
	end

	local ok, err = convert_image(output, content)
	if not ok then
		return ok, err
	end

	return true
end
