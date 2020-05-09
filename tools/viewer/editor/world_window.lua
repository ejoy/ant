local ru          = import_package "ant.render".util
local ecs         = import_package "ant.ecs"
local keymap      = import_package "ant.imguibase".keymap
local imgui       = require "imgui.ant"
local mouse_what  = { 'LEFT', 'RIGHT', 'MIDDLE' }
local mouse_state = { 'DOWN', 'MOVE', 'UP' }

return function(config)
    local rect_x, rect_y = 0, 0
    local rect_w, rect_h = config.width, config.height
    local function isInRect(x, y)
        return (x >= rect_x)
            and (x <= rect_x + rect_w)
            and (y >= rect_y)
            and (y <= rect_y + rect_h)
    end
    local world = ecs.new_world (config)
    world:update_func "init" ()
    world:pub {"resize", rect_w, rect_h}
    local world_update = world:update_func "update"
    local world_tex = assert(ru.get_main_view_rendertexture(world))
    local m = {}
    function m.show()
        rect_x, rect_y = imgui.cursor.GetCursorScreenPos()
        imgui.widget.ImageButton(world_tex,rect_w,rect_h,{frame_padding=0,bg_col={0,0,0,1}})
    end
    function m.update()
        world_update()
        world:clear_removed()
    end
    function m.mouse_wheel(x, y, delta)
        if not isInRect(x, y) then
            return
        end
        world:pub {"mouse_wheel", delta, x - rect_x, y - rect_y}
    end
    function m.mouse(x, y, what, state)
        if not isInRect(x, y) then
            return
        end
        world:pub {"mouse", mouse_what[what] or "UNKNOWN", mouse_state[state] or "UNKNOWN", x - rect_x, y - rect_y}
    end
    function m.keyboard(key, press, state)
        world:pub {"keyboard", keymap[key], press, {
            CTRL 	= (state & 0x01) ~= 0,
            ALT 	= (state & 0x02) ~= 0,
            SHIFT 	= (state & 0x04) ~= 0,
            SYS 	= (state & 0x08) ~= 0,
        }}
    end
    function m.pub(_, data)
        world:pub(data)
    end
    return m
end
