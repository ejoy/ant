local ecs = ...
local world = ecs.world

local lfs   = require "bee.filesystem"
local fs    = require "filesystem"

local blm_editor = ecs.system "editor_bake_lightmap_system"

local blm_mb = world:sub{"BakeLightmap"}
local subprocess = import_package "ant.subprocess"
local LUA = subprocess.tool_exe_path "lua"

local prefabmgr = require "prefab_manager"

local function local_pkg_root_path(prefabfile)
    local rootpath = prefabfile:match "(/pkg/[%w+.]+)"
    return fs.path(rootpath):localpath()
end

local bake_processes = {}
function blm_editor:data_changed()
    for msg in blm_mb:each() do
        local p = msg[2]

        local notwait<const> = true
        local _, prog, progmsg = subprocess.spawn_process({
            cwd = lfs.current_path(),
            LUA,
            "tools/dump-prefab/main.lua",
            local_pkg_root_path(p),
            p,
        }, notwait)

        bake_processes.dump ={
            prog = prog,
            msg = msg,
            prefablefile = p,
        }
        break
    end

    if bake_processes.dump then
        local dump_process = bake_processes.dump
        if not bake_processes.dump.prog:is_running() then
            log.info("[bake process]bake process dump file finish:")
            log.info("[bake process]dump message:\n", dump_process.msg)
            log.info("[bake process]start to bake...")
            local notwait<const> = true
            local p = dump_process.prefablefile
            local _, prog, progmsg = subprocess.spawn_process({
                cwd = lfs.current_path(),
                LUA,
                "tools/baker/main.lua",
                local_pkg_root_path(p),
                p,
            }, notwait)

            bake_processes.bake = {
                prog = prog,
                msg = progmsg,
                prefablefile = p
            }

            bake_processes.dump = nil
        end
    end

    if bake_processes.bake then
        local bp = bake_processes.bake
        if not bp.prog:is_running() then
            log.info("[bake process]bake finish!")
            log.info("[bake process]bake message:\n", bp.msg)

            world:pub{"BakeFinished", bp.prefablefile}
            prefabmgr:save(bp.prefablefile)  --save and reload prefab
            bake_processes.bake = nil
        end
    end
end