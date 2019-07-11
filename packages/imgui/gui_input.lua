local gui_input = {}
gui_input.key_state = {}
gui_input.mouse = {x=0,y=0,delta = {x=0,y=0},last={x=0,y=0}}
local last_mouse = gui_input.mouse.last
local mouse_delta = gui_input.mouse.delta
gui_input.key_down = {}
gui_input.screen_size = {0,0}
local called = {}
gui_input.called = called


function gui_input.mouse_move(x,y)
    local gm = gui_input.mouse
    gm.x = x
    gm.y = y
    -- log(x,last_mouse.x)
    mouse_delta.x = x-last_mouse.x
    mouse_delta.y = y-last_mouse.y
    called.mouse_move = true
end


function gui_input.mouse_wheel(x,y,delta)
    local gm = gui_input.mouse
    gm.scroll = delta
    gm.x = x
    gm.y = y
    called.mouse_wheel = true
end

function gui_input.mouse_click(x, y, what, pressed)
    local gm = gui_input.mouse
    gm.x = x
    gm.y = y
    gm[what] = pressed
    called[what] = true
    called.mouse_click = true
end

function gui_input.keyboard( key, press, state )
    local gk = gui_input.key_state
    gk.ctrl = (state & 0x1) ~= 0
    gk.alt = (state & 0x2) ~= 0
    gk.shift = (state & 0x4) ~= 0
    gk.sys = (state & 0x8) ~= 0
    table.insert(gui_input.key_down,{key,press})
end



function gui_input.clean()
    called = {}
    gui_input.called = called
    gui_input.key_down = {}
    last_mouse.x = gui_input.mouse.x
    last_mouse.y = gui_input.mouse.y
    mouse_delta.x = 0
    mouse_delta.y = 0

end

function gui_input.size(w,h,t)
    gui_input.screen_size[1] = w
    gui_input.screen_size[2] = h
    gui_input.screen_size["type"] = t
end

function gui_input.get_mouse_delta()
    return mouse_delta
end

-----------------------------------------------------
--0:Left 1:Right 2:Middle 3:Button4 4:Button5
function gui_input.is_mouse_pressed(what)
    return gui_input.mouse[what]
end
-----------------------------------------------------

return gui_input