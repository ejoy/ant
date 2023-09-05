local sha1 = require "crypt".sha1

local function byte2hex(c)
	return ("%02x"):format(c:byte())
end

return function (str)
	return sha1(str):gsub(".", byte2hex)
end
