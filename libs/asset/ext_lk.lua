local require = import and import(...) or require

local rawtable = require "rawtable"

return function(filename)
	return rawtable(filename)
end