local crypt = require "crypt"

local str = "abc"

local function byte2hex(c)
	return string.format("%02X", c:byte())
end

local sha1 = crypt.sha1(str):gsub(".", byte2hex)
assert(sha1 == "A9993E364706816ABA3E25717850C26C9CD0D89D")

print("sha1",sha1)
