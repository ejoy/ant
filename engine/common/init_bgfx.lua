if debug.getregistry().BGFX_GET_INTERFACE then
    return
end
local interface = package.preload["bgfx_get_interface"]
debug.getregistry().BGFX_GET_INTERFACE = interface
