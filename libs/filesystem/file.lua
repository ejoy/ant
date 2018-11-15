local file = {}; file.__index = file

require "runtime.vfsio"
local nio = require "nativeio"
function file.create_write_file_stream(filepath, mode)
	return nio.open(filepath, mode)	
end

return file