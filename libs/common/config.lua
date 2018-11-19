local config = {}; config.__index = config

function config.platform()
	local baselib = require "bgfx.baselib"
	return baselib.platform_name
end

return config