local event         = require "event"
local worlds        = require "worlds"
local task          = require "task"
local imgui         = require "imgui"
local import_prefab = require "import_prefab"
local w
local world
local eventPrefab
local wndflags = imgui.flags.Window { "NoTitleBar", "NoBackground", "NoResize", "NoScrollbar", "NoBringToFrontOnFocus" }
--local VIEWER <const> = "/pkg/tools.viewer.prefab_viewer/res/"
local VIEWER <const> = "/pkg/tools.prefab_editor/res/"
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
        name = "ant.tools.prefab_editor",
        ecs = {
            import = {
                "@ant.tools.prefab_editor",
            },
            pipeline = {
                "init",
                "update",
                "exit",
            },
            system = {
                "ant.tools.prefab_editor|init_system",
                "ant.tools.prefab_editor|gizmo_system",
                "ant.tools.prefab_editor|input_system",
                "ant.tools.prefab_editor|camera_system",
                "ant.tools.prefab_editor|gui_system",
                "ant.objcontroller|pickup_system"
            }
        }
    }
    --eventPrefab = world:sub {"editor", "prefab"}
    w.init()
end

function event.dropfiles(filelst)
    world:pub {"OnDropFiles", filelst}
end

function event.update()
    -- for _,_,e in eventPrefab:unpack() do
    --     entities = e
    -- end
end

-- function event.prefab_viewer()
--     for _ in imgui_windows("prefab_viewer", wndflags) do
--         w.show()
--     end
-- end

-- function event.prefab_editor()
--     for _ in imgui_windows("prefab_editor", wndflags) do
--         if imgui.widget.Button "Save" then
--             world:pub {"serialize_prefab", VIEWER .. "root/mesh.prefab"}
--         end
--         for _, eid in ipairs(entities) do
--             local e = world[eid]
--             if e.mesh then
--                 local ies = world:interface "ant.scene|ientity_state"
--                 local change, value = imgui.widget.Checkbox(e.name, ies.can_visible(eid))
--                 if change then
--                     ies.set_state(eid, "visible", value)
--                 end
--             end
--         end
--     end
-- end
