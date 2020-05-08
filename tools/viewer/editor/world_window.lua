local ru          = import_package "ant.render".util
local ecs         = import_package "ant.ecs"
local keymap      = import_package "ant.imguibase".keymap
local imgui       = require "imgui.ant"
local imgui_util  = require "imgui_util"
local mouse_what  = { 'LEFT', 'RIGHT', 'MIDDLE' }
local mouse_state = { 'DOWN', 'MOVE', 'UP' }

local function isInRect(x, y, rect)
    return (x >= rect.x)
        and (x <= rect.x + rect.w)
        and (y >= rect.y)
        and (y <= rect.y + rect.h)
end

return function(config)
    local rect = config.rect
    local world = ecs.new_world {
        width  = rect.w,
        height = rect.h,
        ecs = config.ecs,
    }
    world:update_func "init" ()
    world:pub {"resize", rect.w, rect.h}
    local world_update = world:update_func "update"
    local world_tex = assert(ru.get_main_view_rendertexture(world))

    local m = {}
    function m.update()
        world_update()
        world:clear_removed()

        imgui.windows.SetNextWindowPos(rect.x, rect.y)
        for _ in imgui_util.windows(config.name, imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar" }) do
            imgui.widget.ImageButton(world_tex,rect.w,rect.h,{frame_padding=0,bg_col={0,0,0,1}})
        end
    end
    function m.mouse_wheel(x, y, delta)
        if not isInRect(x, y, rect) then
            return
        end
        world:pub {"mouse_wheel", delta, x - rect.x, y - rect.y}
    end
    function m.mouse(x, y, what, state)
        if not isInRect(x, y, rect) then
            return
        end
        world:pub {"mouse", mouse_what[what] or "UNKNOWN", mouse_state[state] or "UNKNOWN", x - rect.x, y - rect.y}
    end
    function m.keyboard(key, press, state)
        world:pub {"keyboard", keymap[key], press, {
            CTRL 	= (state & 0x01) ~= 0,
            ALT 	= (state & 0x02) ~= 0,
            SHIFT 	= (state & 0x04) ~= 0,
            SYS 	= (state & 0x08) ~= 0,
        }}
    end
    function m.get_world()
        return world
    end
    return m
end
