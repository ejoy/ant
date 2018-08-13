return function()
    bgfx.touch(0)
    bgfx.dbg_text_clear()

    bgfx.dbg_text_image(math.max(ctx.width //2//8 , 20)-20
    , math.max(ctx.height//2//16, 6)-6
    , 40
    , 12
    , s_logo
    , 160
    )

    bgfx.dbg_text_print(0, 1, 0xf, "Color can be changed with ANSI \x1b[9;me\x1b[10;ms\x1b[11;mc\x1b[12;ma\x1b[13;mp\x1b[14;me\x1b[0m code too.");
    bgfx.frame()
end