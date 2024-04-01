local args = table.pack(...)
local output = args[args.n]
local inputs = {}
for i = 1, args.n-1 do
    local file = args[i]
    inputs[i] = assert(file:match "embed/([a-z_]+)%.h$")
end
table.sort(inputs)

local f <close> = assert(io.open(output, "wb"))

local function writeline(data)
    f:write(data)
    f:write "\r\n"
end

writeline "#pragma once"
writeline ""
writeline "#include <map>"
writeline "#include <string_view>"
writeline ""
writeline "using namespace std::literals;"
writeline ""

for _, input in ipairs(inputs) do
    writeline(("#include \"embed/%s.h\""):format(input))
end
writeline ""

writeline "std::map<std::string_view, std::string_view> firmware = {"
for _, input in ipairs(inputs) do
    writeline(("    { \"%s.lua\"sv, embed_%s },"):format(input, input))
end
writeline "};"
