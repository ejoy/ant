local AntDir = ...
local meta; do
    local json = dofile(AntDir.."/pkg/ant.json/main.lua")
    local function readall(path)
        local f <close> = assert(io.open(path, "rb"))
        return f:read "a"
    end
    meta = json.decode(readall(AntDir.."/clibs/imgui/dear_bindings/cimgui.json"))
end

package.path = AntDir.."/clibs/imgui/gen/?.lua"

assert(loadfile(AntDir.."/clibs/imgui/gen/enum.lua"))(AntDir, meta)
assert(loadfile(AntDir.."/clibs/imgui/gen/funcs.lua"))(AntDir, meta)
assert(loadfile(AntDir.."/clibs/imgui/gen/doc.lua"))(AntDir, meta)
