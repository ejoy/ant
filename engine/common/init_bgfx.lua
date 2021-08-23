if debug.getregistry().BGFX_GET_INTERFACE then
    return
end
local interface = package.preload["bgfx_get_interface"]
if interface then
    debug.getregistry().BGFX_GET_INTERFACE = interface
    return
end

local errmsg = "module 'bgfx-core' not found:"
for searchpath in package.cpath:gmatch "[^;]*" do
    local path = searchpath:gsub("%?", "bgfx-core")
    local dll = package.loadlib(path, "bgfx_get_interface")
    if dll then
        debug.getregistry().BGFX_GET_INTERFACE = dll
        return
    else
        errmsg = errmsg .. ("\n\tno file '%s'"):format(path)
    end
end
error(errmsg)
