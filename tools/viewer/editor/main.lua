local editor = import_package "ant.imguibase".editor
local create_world = require "world_window"
local cb = {}
local world = {}

function cb.init()
    world[#world+1] = create_world {
        name = "PrefabViewer",
        rect = {
            w = 1024,
            h = 768,
            x = 0,
            y = 0,
        },
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
                "ant.tools.viewer|init_system",
                "ant.tools.viewer|camera_system",
                "ant.tools.viewer|gui_system",
            }
        }
    }
end

local task = require "task"

function cb.update(delta)
    task.update(delta)
    for _, w in ipairs(world) do
        w.update()
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


local lfs        = require "filesystem.local"
local fs         = require "filesystem"
local sp         = require "subprocess"

local function import(input, voutput)
    local function luaexe()
        local i = -1
        while arg[i] ~= nil do
            i= i - 1
        end
        return arg[i + 1]
    end
    local loutput = voutput:localpath()
    lfs.remove_all(loutput)
    lfs.create_directories(loutput)
    local p = sp.spawn {
        luaexe(),
        "./tools/import_model/import.lua",
        "-i", input,
        "-o", loutput,
        "-v", voutput:string(),
        "--config", "tools/import_model/cfg.txt",
        stderr = true,
        hideWindow = true,
    }
    while p:is_running() do
        task.wait(100)
    end
    assert(p:wait() == 0, p.stderr:read "a")
end

local function importPrefab(filename)
    local output = fs.path "/pkg/ant.tools.viewer/res/"
    import(lfs.path(filename), output)
    return (output / "mesh.prefab"):string()
end

function cb.dropfiles(filelst)
	task.create(function()
        local res = importPrefab(filelst[1])
        world[1].get_world():pub {"reset_prefab", res}
    end)
end
editor.start(cb)
