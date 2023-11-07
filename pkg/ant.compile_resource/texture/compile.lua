local convert_image = require "texture.util"
local depends = require "depends"

return function (content, output, setting, depfiles)
	if not content.path then
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

	depends.add_vpath(depfiles, setting, "/pkg/ant.compile_resource/texture/version.lua")
	local ok, err = convert_image(output, setting, content)
	if not ok then
		return ok, err
	end

	return true
end
