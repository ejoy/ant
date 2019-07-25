local inputmgr = import_package "ant.inputmgr"

local gui_input = {}
gui_input.key_state = {}

local mouse_last = {x=0,y=0}
local mouse_delta = {x=0, y=0}
local mouse_state = {x=0,y=0, delta=mouse_delta, last=nil}
gui_input.mouse_state = mouse_state

local key_down = {}
gui_input.key_down = key_down
gui_input.screen_size = {0,0}
local called = {}
gui_input.called = called

gui_input.MouseLeft = 1
gui_input.MouseRight = 2
gui_input.MouseMiddle = 3
gui_input.MouseButton4 = 4
gui_input.MouseButton5 = 5

local function update_mouse_pos(x, y)
    if mouse_state.last then
        mouse_last.x, mouse_last.y = mouse_state.x, mouse_state.y
        mouse_delta.x = x-mouse_last.x
        mouse_delta.y = y-mouse_last.y
    else
        mouse_last.x, mouse_last.y = x, y
        mouse_state.last = mouse_last

        mouse_delta.x, mouse_delta.y = 0, 0
    end
    
    mouse_state.x, mouse_state.y = x, y
end

function gui_input.mouse(x, y, what, state)
    update_mouse_pos(x, y)
    mouse_state[what] = state
    called[what] = true
end

function gui_input.mouse_wheel(x,y,delta)
    mouse_state.scroll = delta
    update_mouse_pos(x, y)
    called.mouse_wheel = true
end

function gui_input.keyboard( key, press, state )
    gui_input.key_state = inputmgr.translate_key_state(state)
    table.insert(gui_input.key_down,{key,press})
end



function gui_input.clean()
    called = {}
    gui_input.called = called

    key_down = {}
    gui_input.key_down = key_down
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
--gui_input.MouseXXX
function gui_input.is_mouse_pressed(what)
    return gui_input.mouse_state[what]
end
-----------------------------------------------------

return gui_input