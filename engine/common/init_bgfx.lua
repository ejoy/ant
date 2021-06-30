if debug.getregistry().BGFX_GET_INTERFACE then
    return
end
local interface = package.preload["bgfx_get_interface"]
if interface then
    debug.getregistry().BGFX_GET_INTERFACE = interface
    return
end
local path = package.cpath:gsub("^[^;]*", "%1"):gsub("%?", "bgfx-core")
debug.getregistry().BGFX_GET_INTERFACE = assert(package.loadlib(path, "bgfx_get_interface"))
