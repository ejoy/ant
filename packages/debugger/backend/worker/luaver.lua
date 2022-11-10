local rdebug = require 'remotedebug.visitor'

local m = {}

function m.init()
    local version = rdebug.fieldv(rdebug._G, "_VERSION")
    local ver = 0
    if type(version) ~= "string" then
        m.LUAVERSION = 54
        return
    end
    for n in version:gmatch "%d" do
        ver = ver * 10 + (math.tointeger(n) or 0)
    end
    m.LUAVERSION = ver
    if ver == 51 then
        m.isjit = rdebug.fieldv(rdebug._G,"jit") ~= nil
    end
end

return m
