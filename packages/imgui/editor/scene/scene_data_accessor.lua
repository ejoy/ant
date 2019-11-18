local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local cursor    = imgui.cursor
local enum      = imgui.enum
local IO        = imgui.IO

local accessor  = require "editor.config_accessor"
local editor    = import_package "ant.editor"
local task      = editor.task
local hub       = editor.hub
local vfs       = require "vfs"
local scene     = import_package "ant.scene".util
local localfs   = require "filesystem.local"
local inputmgr  = import_package "ant.inputmgr"
local gui_mgr   = require "gui_mgr"
local fs        = require "filesystem"
local serialize = import_package 'ant.serialize'

local function string_list(self,data_tbl,cfg)
    local has_change = false
    local field_name = cfg.name
    local str_list = data_tbl[field_name]
    self:BeginColunms()
    widget.Text(field_name)
    cursor.NextColumn()
    util.PushID(field_name)
    if not self.ui_cache[field_name] then
        local my_cache = {}
        for k,v in ipairs(str_list) do
            my_cache[k] = {
                text = v,
                width = -20,
            }
        end
        self.ui_cache[field_name] = my_cache
    end
    local my_cache = self.ui_cache[field_name]
    for k,v in ipairs(str_list) do
        if widget.InputText("##"..k,my_cache[k]) then
            str_list[k] = tostring(my_cache[k].text)
            has_change = true
        end
        cursor.SameLine()
        if widget.Button("X###"..k) then
            has_change = true
            table.remove(str_list,k)
            table.remove(my_cache,k)
        end
    end
    if widget.Button("+###"..field_name) then
        table.insert(str_list,"")
        table.insert(my_cache,{
            text = "",
            width = -20,
        })
        has_change = true
    end
    util.PopID()
    self:EndColunms()
    return has_change
end

local SceneMeta = {
    {
        name="packages",
        field = "string[]",
        display = string_list,
    },
    {
        name = "systems",
        field = "string[]",
        display = string_list,
    },
}


local scene_data_accessor = {}

scene_data_accessor.SceneMeta = SceneMeta
scene_data_accessor.SerializeExt = "serialize"

--path,config,serialized_str
function scene_data_accessor.save(path,config,serialized_str)

end

function scene_data_accessor.save_scene_file(scene_pkg_path,scene_info)
    local lua_content = accessor.write_lua(scene_info,SceneMeta)
    log.info_a(scene_info,lua_content)
    local f = localfs.open(scene_pkg_path:localpath(),"w")
    assert(f)
    f:write(lua_content)
    f:close()
    return true
end 

--scene_path_obj:/pkg/{xxx}.scene
--scene_serialized_path:nil=>/pkg/{xxx}.serialize
--return config,serialize_str
function scene_data_accessor.load(scene_path,scene_serialized_path)
    if not scene_serialized_path then
        scene_serialized_path = fs.path(scene_path)
        scene_serialized_path:replace_extension(scene_data_accessor.SerializeExt)
    end
    scene_path = fs.path(scene_path)
    assert(fs.exists(scene_serialized_path),
        string.format("serialize file not exists:%s",
            scene_serialized_path:string()))
    local config = nil
    do
        local local_scene_path = scene_path:localpath()
        log("scene_path",scene_path:string())
        log("local_scene_path",local_scene_path:string())
        local r = loadfile(local_scene_path:string(),"t")
        assert(r)
        config = r()
        log.info_a(config)
    end

    local serialize_str = nil
    do
        local f = fs.open(scene_serialized_path,"r")
        local c <close> = setclose(function()
                f:close()
            end)
        serialize_str = f:read("*a")
        log("serialize_str",serialize_str)
    end
    return config,serialize_str
end

--scene_path_obj:/pkg/{xxx}.scene
--scene_serialized_path:nil=>/pkg/{xxx}.serialize
function scene_data_accessor.start_scene(scene_path,scene_serialized_path)
    local config,serialize_str = scene_data_accessor.load(scene_path,scene_serialized_path)
    if not (config  or serialize_str) then
        log.warning("Load scene failed!")
        return false
    end
    return scene_data_accessor._start_scene(config,serialize_str)
end

function scene_data_accessor._start_scene(config,serialize_str)
    local packages = {
        -- "ant.EditorLauncher",
        -- "ant.objcontroller",
        "ant.imgui",
        "ant.testimgui",
        "ant.hierarchy.offline",
    }
    do -- fill packages
        if config.packages then
            local package_map = {}
            for i,v in ipairs(packages) do
                package_map[v] = true
            end

            for i,v in ipairs(config.packages) do
                if not package_map[v] then
                    package_map[v] = true
                    table.insert(packages,v)
                end
            end
        end
    end
    local systems = {
        --"pickup_material_system", 
        "pickup_system",
        -- "obj_transform_system",
        "build_hierarchy_system",
        "editor_watcher_system",
        "editor_operate_gizmo_system",
        "editor_tool_system",
        "visible_system",
        "world_profile_system",
        "init_loader",
        "scenespace_test",
        -- "editor_system"
    }
    do --fill systems
        if config.systems then
            local systems = {}
            for i,v in ipairs(systems) do
                systems[v] = true
            end

            for i,v in ipairs(config.systems) do
                if not systems[v] then
                    systems[v] = true
                    table.insert(systems,v)
                end
            end
        end
    end
    scene_data_accessor.input_queue = inputmgr.queue()
    local world = scene.start_new_world(scene_data_accessor.input_queue, 600, 400, packages, systems,{hub=hub})
    local world_update = scene.loop(world, {
            update = {"timesystem", "message_system"}
        })
    gui_mgr.get("GuiScene"):bind_world(world,world_update,scene_data_accessor.input_queue)
    for _, eid in world:each 'serialize' do
        world:remove_entity(eid)
    end
    world:update_func "delete"()
    world:clear_removed()
    serialize.load_world(world, serialize_str)
end

function scene_data_accessor.start_new_world(raw_path)
    log("raw_path",raw_path,type(raw_path))
    local path = localfs.path(tostring(raw_path))
    log.info_a(path)
    local mapcfg = localfs.dofile(path) 
    log.info_a(mapcfg)
    local pkgname = mapcfg.name
    local pkgsystems = mapcfg.systems
    local packages = {
        -- "ant.EditorLauncher",
        -- "ant.objcontroller",
        "ant.imgui",
        "ant.testimgui",
        "ant.hierarchy.offline",
    }
    local systems = {
        --"pickup_material_system", 
        "pickup_system",
        -- "obj_transform_system",
        "build_hierarchy_system",
        "editor_watcher_system",
        "editor_operate_gizmo_system",
        "editor_tool_system",
        "visible_system",
        "world_profile_system"
        -- "editor_system"
    }

    local pm = require "antpm"
    if not fs.exists(fs.path ("/pkg/"..pkgname)) then
        pkgname = pm.register_package(path:parent_path())
    end
    
    packages[#packages+1] = pkgname
    table.move(pkgsystems, 1, #pkgsystems, #systems+1, systems)
    scene_control.input_queue = inputmgr.queue()
    local world = scene.start_new_world(scene_control.input_queue, 600, 400, packages, systems,{hub=hub})
    local world_update = scene.loop(world, {
            update = {"timesystem", "message_system"}
        })

    -- task.safe_loop(scene.loop(world, {
    --         update = {"timesystem", "message_system"}
    --     }))
    gui_mgr.get("GuiScene"):bind_world(world,world_update,scene_control.input_queue)
end



return scene_data_accessor