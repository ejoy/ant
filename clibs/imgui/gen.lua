local AntDir = ...

package.path = AntDir.."/clibs/imgui/gen/?.lua"

local status = { AntDir = AntDir }
local meta = require "meta"
meta.init(status)

local apis_file <close> = assert(io.open(AntDir.."/clibs/imgui/imgui_lua_funcs.cpp", "wb"))
local docs_file <close> = assert(io.open(AntDir.."/misc/meta/imgui.lua", "wb"))
status.apis_file = apis_file
status.docs_file = docs_file

assert(loadfile(AntDir.."/clibs/imgui/gen/funcs.lua"))(status)
assert(loadfile(AntDir.."/clibs/imgui/gen/doc.lua"))(status)
