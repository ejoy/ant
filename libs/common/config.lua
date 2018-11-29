local config = {}; config.__index = config

local platform = require "platform"
local platname = platform.os()
function config.platform()	
	return platname
end

return config