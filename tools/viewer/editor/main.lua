local editor        = import_package "ant.imguibase".editor
local world_window  = require "world_window"
local imgui         = require "imgui.ant"
local imgui_util    = require "imgui_util"
local task          = require "task"
local import_prefab = require "import_prefab"
local cb = {}
local world = {}
local wndflags = imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar", "NoBringToFrontOnFocus" }

local function create_world(name)
    return function (config)
        local w = world_window(config)
        world[#world+1] = w
        world[name] = w
    end
end

function cb.init()
    create_world "PrefabViewer" {
        width  = 768,
        height = 768,
        ecs = {
            import = {
                "@tools.viewer.prefab_viewer",
            },
            pipeline = {
                "init",
                "update",
                "exit",
            },
            system = {
                "tools.viewer.prefab_viewer|init_system",
                "tools.viewer.prefab_viewer|camera_system",
                "tools.viewer.prefab_viewer|gui_system",
            }
        }
    }
end

function cb.update(delta)
    for _, w in ipairs(world) do
        w.update()
    end
    task.update(delta)
    imgui.windows.SetNextWindowPos(0, 0)
    for _ in imgui_util.windows("Main", wndflags) do
        world["PrefabViewer"].show()
    end
end
function cb.mouse_wheel(x, y, delta)
    for _, w in ipairs(world) do
        w.mouse_wheel(x, y, delta)
    end
end
function cb.mouse(x, y, what, state)
    for _, w in ipairs(world) do
        w.mouse(x, y, what, state)
    end
end
function cb.keyboard(key, press, state)
    for _, w in ipairs(world) do
        w.keyboard(key, press, state)
    end
end

function cb.dropfiles(filelst)
	task.create(function()
        local res = import_prefab(filelst[1])
        world["PrefabViewer"]:pub {"reset_prefab", res}
    end)
end
editor.start(1024, 768, cb)
