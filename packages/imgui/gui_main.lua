local native    = require "window.native"
local window    = require "window"
local imgui     = require "imgui_wrap"
local bgfx      = require "bgfx"
local rhwi      = import_package "ant.render".hardware_interface
local editor    = import_package "ant.editor"
local task      = editor.task
local gui_mgr   = require "gui_mgr"
local gui_input = require "gui_input"
local gui_main  = {}
local attribs   = {}
local main = nil

function gui_main.init(nwh, context, width, height)
    rhwi.init {
        nwh = nwh,
        context = context,
    --  renderer = "DIRECT3D9",
    --  renderer = "OPENGL",
        width = width,
        height = height,
    --  reset = "v",
    }
    attribs.font_size = 18
    attribs.mx = 0
    attribs.my = 0
    attribs.button1 = false
    attribs.button2 = false
    attribs.button3 = false
    attribs.scroll = 0
    attribs.width = width
    attribs.height = height
    attribs.viewid = 255

    imgui.create(attribs.font_size)
    imgui.keymap(native.keymap)

    bgfx.set_view_rect(0, 0, 0, width, height)
    bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

    bgfx.set_view_rect(1, 200, 200, width-100, height-100)
    bgfx.set_view_clear(1, "CD", 0xffff00ff, 1, 0)

    if main.init then
        main.init(nwh, context, width, height)
    end
    

end

function gui_main.size(width,height,type)
    print("callback.size",width,height,type)
    attribs.width = width
    attribs.height = height
    bgfx.reset(width, height, "")
    bgfx.set_view_rect(0, 0, 0, width, height)
    if main.size then
        main.size(width,height,type)
    end
end

function gui_main.char(code)
    imgui.input_char(code)
end

function gui_main.error(err)
    print(err)
    if main.error then
        main.error(err)
    end
end

function gui_main.mouse_move(x,y)
    attribs.mx = x
    attribs.my = y
    gui_input.mouse_move(x,y)
end

function gui_main.mouse_wheel(x,y,delta)
    attribs.scroll = delta
    attribs.mx = x
    attribs.my = y
    gui_input.mouse_wheel(x,y,delta)

end

function gui_main.mouse_click(x, y, what, pressed)
    print("mouse_click",what,pressed)
    if what == 0 then
        attribs.button1 = pressed
    elseif what == 1 then
        attribs.button2 = pressed
    elseif what == 2 then
        attribs.button3 = pressed
    end
    attribs.mx = x
    attribs.my = y
    gui_input.mouse_click(x, y, what, pressed)
end

function gui_main.keyboard(key, press, state)
    imgui.key_state(key, press, state)
    print("key",key,press,state)
    gui_input.keyboard(key, press, state)
end

function gui_main.update()
    gui_mgr.update(attribs)
    gui_input.clean()
    rhwi.ui_frame()
    bgfx.touch(0)
    bgfx.touch(1)
    task.update()
    --todo delete this bgfx code
    rhwi.on_update_end()
    if main.update then
        main.update()
    end
end

function gui_main.exit()
    print("Exit")
    imgui.destroy()
    bgfx.shutdown()
    if main.exit then
        main.exit()
    end
end

local function run(m,args)
    main = m
    window.register(gui_main)
    native.create(args.screen_width or 1024, 
        args.screen_width or 728, 
        args.name or "Ant")
    native.mainloop()
end

return {run = run}


