local mouse_what  = { 'LEFT', 'RIGHT', 'MIDDLE' }
local mouse_state = { 'DOWN', 'MOVE', 'UP' }

local ltask = require "ltask"
local ServiceRmlui; do
    ltask.fork(function ()
        ServiceRmlui = ltask.queryservice "ant.rmlui|rmlui"
    end)
end

local function create(world, type)
    local keymap = require(type.."_keymap")
    local ev = {}
    function ev.mouse_wheel(x, y, delta)
        world:pub {"mouse_wheel", delta, x, y}
    end
    function ev.mouse(x, y, what, state)
        if ServiceRmlui then
            if ltask.call(ServiceRmlui, "mouse", x, y, what, state) then
                return
            end
        end
        world:pub {"mouse", mouse_what[what] or "UNKNOWN", mouse_state[state] or "UNKNOWN", x, y}
    end
    function ev.gesture(...)
        if ServiceRmlui then
            if ltask.call(ServiceRmlui, "gesture", ...) then
                return
            end
        end
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
    function ev.size(w, h)
        world:pub {"resize", w, h}
    end
    return ev
end

return {
    create = create,
}
