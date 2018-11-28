local file = {}; file.__index = file

--local nio = require "nativeio"
local nio = package.loaded.nativeio or io
function file.open(filepath, mode)
	return nio.open(filepath, mode)	
end

return file