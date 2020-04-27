local crypt = require "crypt"
local hash = {}

local function byte2hex(c)
	return ("%02x"):format(c:byte())
end

function hash.sha1(str)
	return crypt.sha1(str):gsub(".", byte2hex)
end

return hash
