local event         = require "event"
local worlds        = require "worlds"
local task          = require "task"
local imgui         = require "imgui.ant"
local import_prefab = require "import_prefab"
local w
local world
local eventPrefab
local entities = {}
local wndflags = imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar", "NoBringToFrontOnFocus" }
local VIEWER <const> = "/pkg/tools.viewer.prefab_viewer/res/"

local function ONCE(t, s)
    if not s then return t end
end
local windiwsBegin = imgui.windows.Begin
local windiwsEnd = setmetatable({}, { __close = imgui.windows.End })
local function imgui_windows(...)
	windiwsBegin(...)
	return ONCE, windiwsEnd, nil, windiwsEnd
end

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
    w.init()
end

function event.dropfiles(filelst)
    task.create(function()
        import_prefab(filelst[1], VIEWER .. "root.glb")
        world:pub {"instance_prefab", VIEWER .. "root.glb|mesh.prefab"}
    end)
end

function event.update()
    for _,_,e in eventPrefab:unpack() do
        entities = e
    end
end

function event.prefab_viewer()
    for _ in imgui_windows("prefab_viewer", wndflags) do
        w.show()
    end
end

function event.prefab_editor()
    for _ in imgui_windows("prefab_editor", wndflags) do
        if imgui.widget.Button "Save" then
            world:pub {"serialize_prefab", VIEWER .. "root.prefab"}
        end
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
