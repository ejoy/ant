local sp = require "subprocess"
local fs = require "filesystem.cpp"
local LUAC = fs.exe_path():parent_path() / "luac.exe"

return function (input, output)
    local proc = assert(sp.spawn {
        LUAC,
        "-o", output,
        input
    })
    proc:wait()
end
