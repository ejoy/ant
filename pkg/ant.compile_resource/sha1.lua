local fastio = require "fastio"

return function (str)
	return fastio.str2sha1(str)
end
