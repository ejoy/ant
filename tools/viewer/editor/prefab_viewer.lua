local event         = require "event"
local worlds        = require "worlds"
local task          = require "task"
local imgui         = require "imgui.ant"
local import_prefab = require "import_prefab"
local imgui_util    = require "imgui_util"
local w
local world
local eventPrefab
local entities = {}
local wndflags = imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar", "NoBringToFrontOnFocus" }

function event.init()
    w, world = worlds.create "PrefabViewer" {
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
    eventPrefab = world:sub {"editor", "prefab"}
end

function event.dropfiles(filelst)
    task.create(function()
        local res = import_prefab(filelst[1])
        world:pub {"reset_prefab", res}
    end)
end

function event.update()
    for _,_,e in eventPrefab:unpack() do
        entities = e
    end
end

function event.prefab_viewer()
    for _ in imgui_util.windows("prefab_viewer", wndflags) do
        w.show()
    end
end

function event.prefab_editor()
    for _ in imgui_util.windows("prefab_editor", wndflags) do
        for _, eid in ipairs(entities) do
            local e = world[eid]
            if e.rendermesh then
                local change, value = imgui.widget.Checkbox(e.name, e.can_render == true)
                if change then
                    e.can_render = value
                end
            end
        end
    end
end
