local pm        = require "antpm"
local lfs       = require "filesystem.local"
local runtime = import_package "ant.imguibase".runtime_cb
local scene_runner = require "scene_runner"

local project_runner = {}
local project = {}

--to be deleted
function project_runner.run(project_dir)
    --get project path
    do
        local pkg_name = pm.register_package(lfs.path(project_dir))
        assert(pkg_name == "project")
        pm.import "project"
    end

    local project_config = nil
    local entry_scene = nil
    do
        local project_config_path = project_dir.."/.project"
        local r = loadfile(project_config_path)
        assert(r)
        project_config = r()
        entry_scene = project_config.entry_scene
        assert(entry_scene,"Can't start project:not entry scene.")
    end
    project.config = project_config
    --rigister project pkgs
    do
        local config_external_packages = project_config.external_packages
        if config_external_packages then
            for i,pkg_path in ipairs(config_external_packages) do
                local _path = lfs.path(pkg_path)
                local pkg_data = pm.get_registered(_path)
                if not pkg_data then
                    pm.register_package(_path)
                end
            end
        end
        local config_inner_packages = project_config.inner_packages
        local inner_packages = {}
        if config_inner_packages then
            for i,pkg_path in ipairs(config_inner_packages) do
                local _path = lfs.path(project_dir.."/"..pkg_path)
                local pkg_data = pm.get_registered(_path)
                if not pkg_data then
                    pm.register_package(_path)
                end
            end
        end
    end

    --read entry_scene
    local scene_cfg = nil
    local serialize_world
    do
        local scene_path = project_dir.."/"..entry_scene
        local r = loadfile(scene_path)
        assert(r,"load scene config failed.")
        scene_cfg = r()
        local scene_pathobj = lfs.path(scene_path)
        scene_pathobj:replace_extension("serialize")
        local ser_f = lfs.open(scene_pathobj,"r")
        serialize_world = ser_f:read("*a")
        ser_f:close()
    end

    --start scene
    local serialize = import_package 'ant.serialize'
    local single_world = import_package "ant.imguibase".single_world

    local ori_init = single_world.init
    single_world.init = function(...)
        ori_init(...)
        local world = single_world.world
        for _, eid in world:each 'serialize' do
            world:remove_entity(eid)
        end
        world:update_func "delete"()
        world:clear_removed()
        serialize.load_world(world, serialize_world)
        table.insert(project_runner.worlds,world)
        return world
    end
    single_world.start(scene_cfg.packages, scene_cfg.systems)
end

function project_runner.start(project_dir)
    project.project_dir = project_dir
    project.config = project_runner._load_project(project_dir)
    runtime.start(project_runner)
end

function project_runner._load_project(project_dir)
    do
        local pkg_name = pm.register_package(lfs.path(project_dir))
        assert(pkg_name == "project")
        pm.import "project"
    end

    local project_config = nil
    local entry_scene = nil
    do
        local project_config_path = project_dir.."/.project"
        local r = loadfile(project_config_path)
        assert(r)
        project_config = r()
        entry_scene = project_config.entry_scene
        assert(entry_scene,"Can't start project:not entry scene.")
    end

    --rigister project pkgs
    do
        local config_external_packages = project_config.external_packages
        if config_external_packages then
            for i,pkg_path in ipairs(config_external_packages) do
                local _path = lfs.path(pkg_path)
                local pkg_data = pm.get_registered(_path)
                if not pkg_data then
                    pm.register_package(_path)
                end
            end
        end
        local config_inner_packages = project_config.inner_packages
        local inner_packages = {}
        if config_inner_packages then
            for i,pkg_path in ipairs(config_inner_packages) do
                local _path = lfs.path(project_dir.."/"..pkg_path)
                local pkg_data = pm.get_registered(_path)
                if not pkg_data then
                    pm.register_package(_path)
                end
            end
        end
    end
    return project_config
end


function project_runner.init(nwh, context, width, height)
    --load-project()
    local window = require "window"
    --set title
    local project_name = lfs.path(project.project_dir):filename():string()
    window.set_title(nwh,"Ant "..tostring(project_name))
    local scene_path = project.project_dir.."/"..project.config.entry_scene
    scene_runner.start(scene_path,width, height)
end

function project_runner.mouse_wheel(x, y, delta)
    scene_runner.mouse_wheel(x, y, delta)
end

function project_runner.mouse(x, y, what, state)
    scene_runner.mouse(x, y, what, state)
end

function project_runner.touch(x, y, id, state)
    scene_runner.touch(x, y, id, state)
end

function project_runner.keyboard(key, press, state)
    scene_runner.keyboard(key, press, state)
end

function project_runner.size(width,height,_)
    scene_runner.size(width,height,_)
end

function project_runner.exit()

end

function project_runner.update()
    return scene_runner.update()
end



return project_runner