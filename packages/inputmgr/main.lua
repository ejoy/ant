local mouse_what  = { 'LEFT', 'RIGHT', 'MIDDLE' }
local mouse_state = { 'DOWN', 'MOVE', 'UP' }

local function create(world, type)
    local keymap = require(type.."_keymap")
    local ev = {}
    function ev.mouse_wheel(x, y, delta)
        world:pub {"mouse_wheel", delta, x, y}
    end
    function ev.mouse(x, y, what, state)
        world:pub {"mouse", mouse_what[what] or "UNKNOWN", mouse_state[state] or "UNKNOWN", x, y}
    end
    function ev.touch(x, y, id, state)
        world:pub {"touch", id, mouse_state[state] or "UNKNOWN", x, y}
    end
    function ev.keyboard(key, press, state)
        world:pub {"keyboard", keymap[key], press, {
            CTRL	= (state & 0x01) ~= 0,
            ALT		= (state & 0x02) ~= 0,
            SHIFT	= (state & 0x04) ~= 0,
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
