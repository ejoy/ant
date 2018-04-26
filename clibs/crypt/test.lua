local crypt = require "crypt"

local str = "abc"

local function byte2hex(c)
	return string.format("%02X", c:byte())
end

local sha1 = crypt.sha1(str)

local hex = sha1:gsub(".", byte2hex)
assert(hex == "A9993E364706816ABA3E25717850C26C9CD0D89D")
print("sha1",hex)

local encoder = crypt.sha1_encoder():init()	-- init can be omit
encoder:update(str)
encoder:update(str)
assert(crypt.sha1(str..str) == encoder:final())
print("uuid", crypt.uuid())

