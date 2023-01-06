local mouse_what  = { 'LEFT', 'RIGHT', 'MIDDLE' }
local mouse_state = { 'DOWN', 'MOVE', 'UP' }
local touch_state = { 'START', 'MOVE', 'END', "CANCEL" }

local function create(world, type)
    local keymap = require(type.."_keymap")
    local ev = {}
    function ev.mouse_wheel(x, y, delta)
        world:pub {"mouse_wheel", delta, x, y}
    end
    function ev.mouse(x, y, what, state)
        world:pub {"mouse", mouse_what[what] or "UNKNOWN", mouse_state[state] or "UNKNOWN", x, y}
    end
    function ev.touch(state, data)
        world:pub {"touch", touch_state[state] or "UNKNOWN", data}
    end
    function ev.gesture(...)
        world:pub {"gesture", ...}
    end
    function ev.keyboard(key, press, state)
        world:pub {"keyboard", keymap[key], press, {
            CTRL	= (state & 0x01) ~= 0,
            SHIFT	= (state & 0x02) ~= 0,
            ALT		= (state & 0x04) ~= 0,
            SYS		= (state & 0x08) ~= 0,
        }}
    end
    function ev.char(char)
        world:pub {"char", char}
    end
    function ev.size(w, h)
        world:pub {"resize", w, h}
    end
    return ev
end

return {
    create = create,
}
