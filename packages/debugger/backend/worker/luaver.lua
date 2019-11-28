local rdebug = require 'remotedebug.visitor'

local m = {}

function m.init()
    local version = rdebug.fieldv(rdebug._G, "_VERSION")
    local ver = 0
    for n in version:gmatch "%d" do
        ver = ver * 10 + (math.tointeger(n) or 0)
    end
    m.LUAVERSION = ver
end

return m
