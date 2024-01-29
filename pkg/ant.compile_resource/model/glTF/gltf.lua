local json = import_package "ant.json"
local base64 = require "model.glTF.base64"
local fs = require "bee.filesystem"

local function readall(filename)
    local f <close> = assert(io.open(filename, "rb"))
    return f:read "a"
end

local function decode(filename, fetch)
    local info = json.decode(readall(filename))
    if info.buffers then
        for _, b in ipairs(info.buffers) do
            local data = b.uri
            if data:sub(1, 37) == "data:application/octet-stream;base64," then
                b.bin = base64.decode(data:sub(38))
            else
                b.bin = fetch(b.uri)
            end
            b.uri = nil
        end
    end
    return info
end

return {
    decode = decode,
}
