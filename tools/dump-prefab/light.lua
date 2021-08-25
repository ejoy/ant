local serialize = import_package "ant.serialize"
local crypt = require "crypt"

local function byte2hex(c)
	return ("%02x"):format(c:byte())
end
local function sha1(str)
	return crypt.sha1(str):gsub(".", byte2hex)
end

return {
    load = function (l)
        local bin = serialize.pack(l)
        return {
            name = "light-" .. sha1(bin),
            value = l,
        }
    end,
}