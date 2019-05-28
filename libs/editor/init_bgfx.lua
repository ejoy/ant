if debug.getregistry().BGFX_GET_INTERFACE then
    return
end
local path = assert(package.searchpath("bgfx-core", package.cpath))
local interface = assert(package.loadlib(path, "bgfx_get_interface"))
debug.getregistry().BGFX_GET_INTERFACE = interface
