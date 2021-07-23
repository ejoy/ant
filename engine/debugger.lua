local function dofile(filename, ...)
    local f = assert(io.open(filename))
    local str = f:read "a"
    f:close()
    return assert(load(str, "=(debugger.lua)"))(...)
end

local path = os.getenv "LUA_DEBUG_PATH"
if path then
    return dofile(path .. "/script/debugger.lua", path)
        : attach {}
end
