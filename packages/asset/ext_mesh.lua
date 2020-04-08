local assetutil = import_package "ant.fileconvert".util
local thread = require "thread"


return { 
	loader = function (filename)
		local _, binary = assetutil.parse_embed_file(filename)
		return thread.unpack(binary)
	end,
	unloader = function(res)
	end,
}
