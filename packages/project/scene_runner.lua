local inputmgr = import_package "ant.imguibase".inputmgr
local lfs       = require "filesystem.local"
local rxbus = import_package "ant.rxlua".RxBus

local scene_runner = {
    width = 1280,
    height = 720,
}

local world_list = {}
local SceneFills = {
    packages = {
        "ant.project",
        "ant.imguibase"
    },
    systems = {
        "script_system",
        "imgui_runtime_system"
    }
}

local function fill_item_to_list(ori_list,fill_list)
    local temp_dic = {} 
    for k,v in ipairs(ori_list) do
        temp_dic[v] = true
    end
    for k,v in ipairs(fill_list) do
        if not temp_dic[v] then
            temp_dic[v] = true
            table.insert(ori_list,v)
        end
    end
    return ori_list
end

--exp:project_test/scenes/first_scene.scene
function scene_runner.start(scene_path,width, height)
    --read entry_scene
    scene_runner.width = width or scene_runner.width
    scene_runner.height = width or scene_runner.height

    local scene_cfg = nil
    local serialize_world
    local script_obj = nil
    do
        
        local r = loadfile(scene_path)
        assert(r,"load scene config failed.")
        scene_cfg = r()
        local scene_pathobj = lfs.path(scene_path)
        scene_pathobj:replace_extension("serialize")

        local ser_f = lfs.open(scene_pathobj,"r")
        serialize_world = ser_f:read("*a")
        ser_f:close()
        local script_path = scene_path:sub(1,-6).."lua"
        local script_f = loadfile(script_path)
        if script_f then
            script_obj = script_f()
        end
    end
    local packages = scene_cfg.packages
    local systems = scene_cfg.systems

    fill_item_to_list(packages,SceneFills.packages)
    fill_item_to_list(systems,SceneFills.systems)

    --start scene
    local serialize = import_package 'ant.serialize'
    local single_world = import_package "ant.imguibase".single_world
    local su = import_package "ant.scene".util

    local world = su.start_new_world(
            width, height, 
            packages, systems,
            {callback = script_obj,rxbus = rxbus},
        )
    world_update = su.loop(world)
    single_world.world = world

    local world_dic = {
        world = world,
        input_queue = iq,
        world_update = world_update,
    }

    --load serialize
    local world = single_world.world
    for _, eid in world:each 'serialize' do
        world:remove_entity(eid)
    end
    world:update_func "delete"()
    world:clear_removed()
    serialize.load_world(world, serialize_world)
    table.insert(world_list,world_dic)
    return world_dic
end

function scene_runner.init(nwh, context, width, height)
    
end

function scene_runner.mouse_wheel(x, y, delta)
    for k,world_obj in ipairs(world_list) do
        world_obj.input_queue:push("mouse_wheel", x, y, delta)
    end
end

function scene_runner.mouse(x, y, what, state)
    for k,world_obj in ipairs(world_list) do
        world_obj.input_queue:push("mouse", x, y, inputmgr.translate_mouse_button(what), inputmgr.translate_mouse_state(state))
    end
end

function scene_runner.touch(x, y, id, state)
    for k,world_obj in ipairs(world_list) do
        world_obj.input_queue:push("touch", x, y, id, inputmgr.translate_mouse_state(state))
    end
end

function scene_runner.keyboard(key, press, state)
    for k,world_obj in ipairs(world_list) do
        world_obj.input_queue:push("keyboard", keymap[key], press, inputmgr.translate_key_state(state))
    end
end

function scene_runner.size(width,height,_)
    for k,world_obj in ipairs(world_list) do
        world_obj.input_queue:push("resize", width,height)
    end
end

function scene_runner.exit()

end

function scene_runner.update()
    local updated = false
    for k,world_obj in ipairs(world_list) do
        world_obj.world_update()
        updated = true
    end
    return updated
end

return scene_runner