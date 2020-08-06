local editor      = import_package "ant.imguibase".editor
local ecs         = import_package "ant.ecs"
local imgui       = require "imgui.ant"

local function create_world(config)
    local context = editor.get_context()
    local rect_x, rect_y = 0, 0
    local rect_w, rect_h = config.width, config.height
    local function isInRect(x, y)
        return (x >= rect_x)
            and (x <= rect_x + rect_w)
            and (y >= rect_y)
            and (y <= rect_y + rect_h)
    end
    local world = ecs.new_world (config)
    local irender = world:interface "ant.render|irender"
    irender.create_blit_queue{w=config.width, h=config.height}
    editor.init_world(world)
    local world_update = world:update_func "update"
    local world_tex
    local m = {}
    function m.init()
        world:pub {"resize", rect_w, rect_h}
        world:update_func "init" ()
        imgui.SetCurrentContext(context)
        local irender = world:interface "ant.render|irender"
        world_tex = assert(irender.get_main_view_rendertexture())
    end
    -- function m.show()
    --     rect_x, rect_y = imgui.cursor.GetCursorScreenPos()
    --     rect_x, rect_y = math.max(rect_x, 0), math.max(rect_y, 0)
    --     imgui.widget.ImageButton(world_tex,rect_w,rect_h,{frame_padding=0,bg_col={0,0,0,1}})
    -- end
    function m.update()
        imgui.SetCurrentContext(world.imgui_context)
        world_update()
        world:clear_removed()
        imgui.SetCurrentContext(context)
    end
    function m.mouse_wheel(x, y, delta)
        -- if not isInRect(x, y) then
        --     return
        -- end
        imgui.SetCurrentContext(world.imgui_context)
        world:signal_emit("mouse_wheel", x - rect_x, y - rect_y, delta)
        imgui.SetCurrentContext(context)
    end
    function m.mouse(x, y, what, state)
        -- if not isInRect(x, y) then
        --     return
        -- end
        imgui.SetCurrentContext(world.imgui_context)
        world:signal_emit("mouse", x - rect_x, y - rect_y, what, state)
        imgui.SetCurrentContext(context)
    end
    function m.keyboard(key, press, state)
        imgui.SetCurrentContext(world.imgui_context)
        world:signal_emit("keyboard", key, press, state)
        imgui.SetCurrentContext(context)
    end
    function m.char(key, press, state)
        imgui.SetCurrentContext(world.imgui_context)
        world:signal_emit("char", key, press, state)
        imgui.SetCurrentContext(context)
    end
    function m.size(width, height)
        imgui.SetCurrentContext(world.imgui_context)
        world:pub {"resize", width, height}
        imgui.SetCurrentContext(context)
    end
    return m, world
end

local worlds = {}

function worlds.create(name)
    return function (config)
        local w, world = create_world(config)
        worlds[#worlds+1] = w
        return w, world
    end
end

return worlds
