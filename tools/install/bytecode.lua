local sp = require "bee.subprocess"
local fs = require "bee.filesystem"
local LUAC = fs.exe_path():parent_path() / "luac.exe"

return function (input, output)
    local proc = assert(sp.spawn {
        LUAC,
        "-o", output,
        input
    })
    proc:wait()
end
