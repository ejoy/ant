local path, pid = ...
if _VERSION == nil
    or type == nil
    or assert == nil
    or tostring == nil
    or error == nil
    or dofile == nil
    or io == nil
    or os == nil
    or debug == nil
    or package == nil
    or string == nil
then
    return "wait initialized"
end

local is_luajit = tostring(assert):match('builtin') ~= nil
if is_luajit and jit == nil then
    return "wait initialized"
end

local function dofile(filename)
    local load = _VERSION == "Lua 5.1" and loadstring or load
    local f = assert(io.open(filename))
    local str = f:read "*a"
    f:close()
    return assert(load(str, "=(debugger.lua)"))(filename)
end
local function isLatest()
    local ipc = dofile(path.."/script/common/ipc.lua")
    local fd = ipc(path, pid, "luaVersion")
    local result = false
    if fd then
        result = "lua-latest" == fd:read "a"
        fd:close()
    end
    return result
end
local dbg = dofile(path.."/script/debugger.lua")
dbg:start {
    address = ("@%s/tmp/pid_%s"):format(path, pid),
    latest = isLatest(),
}
dbg:event "wait"
return "ok"