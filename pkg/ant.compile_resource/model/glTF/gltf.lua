local json = import_package "ant.json"

local function readall(filename)
    local f <close> = assert(io.open(filename, "rb"))
    return f:read "a"
end

local function decode(filename, fetch)
    local info = json.decode(readall(filename))
    if info.buffers then
        for _, b in ipairs(info.buffers) do
            b.bin = fetch(b.uri)
            b.uri = nil
        end
    end
    return info
end

return {
    decode = decode,
}
