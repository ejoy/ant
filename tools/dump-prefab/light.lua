local serialize = import_package "ant.serialize"
local sha1 = require "sha1"
return {
    load = function (l)
        local bin = serialize.pack(l)
        return {
            name = "light-" .. sha1(bin),
            value = l,
        }
    end,
}