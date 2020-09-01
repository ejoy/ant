package.path = "engine/?.lua;tools/fileserver/?.lua"
require "bootstrap"
local server = require "fileserver"

local function luaexe()
    local i = -1
    while arg[i] ~= nil do i = i - 1 end
    return arg[i + 1]
end

server.init {
    lua = luaexe(),
    default_repo = arg[1]
}

server.listen("0.0.0.0", 2018)
server.mainloop()
