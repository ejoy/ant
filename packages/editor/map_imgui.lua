local keymap = (import_package "ant.inputmgr").keymap

local str_map = { 
    [0] = "LEFT",
    [1] = "RIGHT",
    [2] = "MIDDLE",
    [3] = "BUTTON4",
    [4] = "BUTTON5",
    alt = "ALT",
    ctrl = "CTRL",
    sys = "SYS",
    shift = "SHIFT",
    double = "DOUBLE",
}

local pressnames = {
    [0] = false,
    [1] = true,
}

local function translate_status(key_state,mouse_state)
    local t = {}
    for k,v in ipairs(mouse_state) do
        if v then
            local str = str_map[k]
            t[str] = true
        end
    end
    for k,v in pairs(key_state) do
        if v then
            local str = str_map[k]
            t[str] = true
        end
    end

    return t
end

return function (msgqueue, ctrl)    
    ctrl.button_cb = function(_, btn, press, x, y, key_state, mouse_state)
        msgqueue:push("mouse_click", str_map[btn], press, x, y, translate_status(key_state,mouse_state))
        -- print_a("mouse_click", str_map[btn], press, x, y, translate_status(key_state,mouse_state))
    end

    ctrl.motion_cb = function(_, x, y, key_state, mouse_state)
        msgqueue:push("mouse_move", x, y, translate_status(key_state,mouse_state))
    end

    ctrl.wheel_cb = function(_, delta, x, y)
        -- not use status right now
        msgqueue:push("mouse_wheel", x, y, delta)
    end

    ctrl.keypress_cb = function(_, key, press, key_state, mouse_state)
        -- print_a(key_state, mouse_state)
        msgqueue:push("keyboard", keymap[key & 0x0FFFFFFF], press,translate_status(key_state,mouse_state))
    end
    ctrl.resize_cb = function(_, a, b)
        msgqueue:push("resize", a, b)
    end
end