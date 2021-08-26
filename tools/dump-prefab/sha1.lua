local crypt = require "crypt"

local function byte2hex(c)
	return ("%02x"):format(c:byte())
end
local function sha1(str)
	return crypt.sha1(str):gsub(".", byte2hex)
end

return sha1