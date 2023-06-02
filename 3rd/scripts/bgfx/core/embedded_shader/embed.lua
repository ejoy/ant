local output = arg[1]
table.remove(arg, 1)
local input = arg

local fs = require "bee.filesystem"

local function readfile(filename)
    local f <close> = assert(io.open(filename, "rb"))
    return f:read "a"
end

local function writeline(f, data)
    f:write(data)
    f:write "\n"
end

local function embed_file(f, path, name, type)
    local data = readfile(path)
    writeline(f, ([[static const uint8_t %s_%s[%d] =]]):format(name, type, #data))
    writeline(f, "{")
    local n = #data - #data % 16
    for i = 1, n, 16 do
        local b00, b01, b02, b03, b04, b05, b06, b07, b08, b09, b0a, b0b, b0c, b0d, b0e, b0f = string.byte(data, i, i + 15)
        writeline(f, ("\t0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, // %s"):format(b00, b01, b02, b03, b04, b05, b06, b07, b08, b09, b0a, b0b, b0c, b0d, b0e, b0f, string.sub(data, i, i + 15):gsub("[^%g ]", ".")))
    end

    f:write("\t")
    local padding = 16 - #data % 16
    for i = n+1, #data do
        local b = string.byte(data, i)
        f:write(("0x%02x, "):format(b))
    end
    if padding ~= 16 then
        f:write(string.rep("      ", padding))
        writeline(f, ("// %s"):format(string.sub(data, n+1, #data):gsub("[^%g ]", ".")))
    end
    writeline(f, "};")
end

local name = fs.path(output):stem():stem():string()

local f <close> = assert(io.open(output, "wb"))

local shaders <const> = {
    "glsl",
    "essl",
    "spv",
    "dx9",
    "dx11",
    "mtl",
}
for i, v in ipairs(shaders) do
    embed_file(f, input[i], name, v)
end
writeline(f, ("extern const uint8_t* %s_pssl;"):format(name))
writeline(f, ("extern const uint32_t %s_pssl_size;"):format(name))
