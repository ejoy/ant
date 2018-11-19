local file = {}; file.__index = file

local nio = require "nativeio"
function file.open(filepath, mode)
	return nio.open(filepath, mode)	
end

return file