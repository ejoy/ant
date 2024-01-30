local AntDir = ...
local meta; do
    local json = dofile(AntDir.."/pkg/ant.json/main.lua")
    local function readall(path)
        local f <close> = assert(io.open(path, "rb"))
        return f:read "a"
    end
    meta = json.decode(readall(AntDir.."/clibs/imgui/dear_bindings/cimgui.json"))
end

loadfile(AntDir.."/clibs/imgui/gen/enum.lua")(AntDir, meta)
loadfile(AntDir.."/clibs/imgui/gen/funcs.lua")(AntDir, meta)
loadfile(AntDir.."/clibs/imgui/gen/doc.lua")(AntDir, meta)
