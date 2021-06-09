if debug.getregistry().BGFX_GET_INTERFACE then
    return
end
local interface = package.preload["bgfx_get_interface"]
if interface then
    debug.getregistry().BGFX_GET_INTERFACE = interface
    return
end
local path = assert(package.searchpath("bgfx-core", package.cpath))
debug.getregistry().BGFX_GET_INTERFACE = assert(package.loadlib(path, "bgfx_get_interface"))
