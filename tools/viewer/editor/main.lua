local editor = import_package "ant.imguibase".editor
local ru     = import_package "ant.render".util
local su     = import_package "ant.scene"
local imgui  = require "imgui.ant"

local cb = {}

local world

function cb.init()
    world = su.create_world()
    world.init {
        width  = 1024,
        height = 768,
        ecs = {
            import = {
                "@ant.tools.viewer",
            },
            pipeline = {
                "init",
                "update",
                "exit",
            },
            system = {
                "ant.tools.viewer|init_loader",
            }
        }
    }
end
function cb.update()
    world.update()
    imgui.windows.SetNextWindowPos(0, 0)
    imgui.windows.Begin("TEST", imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar" })
    local world_tex = ru.get_main_view_rendertexture(world:get_world())
    if world_tex then
        imgui.widget.ImageButton(world_tex,1024,768,{frame_padding=0,bg_col={0,0,0,1}})
    end
    imgui.windows.End()
end

local keymap      = import_package "ant.imguibase".keymap
local mouse_what  = { 'LEFT', 'RIGHT', 'MIDDLE' }
local mouse_state = { 'DOWN', 'MOVE', 'UP' }
function cb.mouse_wheel(x, y, delta)
	world.mouse_wheel(x, y, delta)
end
function cb.mouse(x, y, what, state)
	world.mouse(x, y, mouse_what[what] or "UNKNOWN", mouse_state[state] or "UNKNOWN")
end
function cb.touch(x, y, id, state)
	world.touch(x, y, mouse_state[state] or "UNKNOWN", id)
end
function cb.keyboard(key, press, state)
	world.keyboard(keymap[key], press, {
		CTRL 	= (state & 0x01) ~= 0,
		ALT 	= (state & 0x02) ~= 0,
		SHIFT 	= (state & 0x04) ~= 0,
		SYS 	= (state & 0x08) ~= 0,
	})
end
function cb.size(w, h)
    world.size(w, h)
end
function cb.dropfiles(filelst)
    world:get_world():pub {"dropfiles", filelst}
end

editor.start(cb)
