local input, output = ...

local function readfile(filename)
    local f <close> = assert(io.open(filename, "rb"))
    return f:read "a"
end

local fs = require "bee.filesystem"

local name = fs.path(output):stem():string()
local f <close> = assert(io.open(output, "wb"))
local function writeline(data)
    f:write(data)
    f:write "\r\n"
end

writeline [[#pragma once]]
writeline ""

local data = readfile(input)
if #data >= 16380 then
    writeline(([[static const char embed_hex_%s[] = {]]):format(name))
    local n = #data - #data % 16
    for i = 1, n, 16 do
        local b00, b01, b02, b03, b04, b05, b06, b07, b08, b09, b0a, b0b, b0c, b0d, b0e, b0f = string.byte(data, i, i + 15)
        writeline(("0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,0x%02x,"):format(b00, b01, b02, b03, b04, b05, b06, b07, b08, b09, b0a, b0b, b0c, b0d, b0e, b0f))
    end
    for i = n+1, #data do
        local b = string.byte(data, i)
        f:write(("0x%02x,"):format(b))
    end
    f:write "0x00,"
    writeline ""
    writeline [[};]]
    writeline(([[static constexpr std::string_view embed_%s { embed_hex_%s, sizeof(embed_hex_%s)-1 };]]):format(name, name, name))
else
    f:write(([[static constexpr std::string_view embed_%s = R"firmware(]]):format(name))
    f:write(data)
    f:write([[)firmware"sv;]])
    f:write "\r\n"
end
