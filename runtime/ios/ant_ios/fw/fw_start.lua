return function (window_handle, width, height, ...)
    ctx.width = width
    ctx.height = height

    bgfx.set_platform_data({nwh = window_handle})
    bgfx.init()


    bgfx.set_debug "T"
    bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

    bgfx.set_view_rect(0, 0, 0, width, height)
    bgfx.reset(width, height, "v")
    ctx.width = width
    ctx.height = height
    init_flag = true

    local bgfx_cb = bgfx.bgfx_cb
    print("bgfx_cb", bgfx_cb)
end