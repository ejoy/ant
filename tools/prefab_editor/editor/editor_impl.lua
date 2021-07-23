local event         = require "event"
local worlds        = require "worlds"
local task          = require "task"
local imgui         = require "imgui"
local import_prefab = require "import_prefab"
local w
local world
local wndflags = imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar", "NoBringToFrontOnFocus" }
local function ONCE(t, s)
    if not s then return t end
end
local windiwsBegin = imgui.windows.Begin
local windiwsEnd = setmetatable({}, { __close = imgui.windows.End })
local function imgui_windows(...)
	windiwsBegin(...)
	return ONCE, windiwsEnd, nil, windiwsEnd
end

function event.init(pw, ph)
    w, world = worlds.create "prefab_editor" {
        width  = pw,
        height = ph,
        name = "tools.prefab_editor",
        ecs = {
            import = {
                "@tools.prefab_editor",
            },
            pipeline = {
                "init",
                "update",
                "exit",
            },
            system = {
                "tools.prefab_editor|init_system",
                "tools.prefab_editor|gizmo_system",
                "tools.prefab_editor|input_system",
                "tools.prefab_editor|camera_system",
                "tools.prefab_editor|gui_system",
                "ant.objcontroller|pickup_system"
            }
        }
    }
    w.init()
end

function event.dropfiles(filelst)
    world:pub {"OnDropFiles", filelst}
end

function event.update()
end

function event.exit()
end
