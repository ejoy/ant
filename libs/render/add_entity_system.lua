local ecs = ...
local world = ecs.world
local fs_util = require "filesystem.util"
local component_util = require "render.components.util"
local lu = require "render.light.util"
local mu = require "math.util"
local bgfx = require "bgfx"

local add_entity_sys = ecs.system "add_entities_system"

add_entity_sys.singleton "math_stack"
add_entity_sys.singleton "constant"

add_entity_sys.depend "constant_init_sys"
add_entity_sys.dependby "iup_message"


function add_entity_sys:init()
    local ms = self.math_stack
    --[[
        do
            local leid = lu.create_directional_light_entity(world)
            local lentity = world[leid]
            local light = lentity.light.v
            light.rot = {135, 0, 0}
        end
    --]]

    do
        local bunny_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local bunny = world[bunny_eid]
        bunny.name.n = "bunny"

        -- should read from serialize file        
        ms(bunny.scale.v, {0.2, 0.2, 0.2, 0}, "=")
        ms(bunny.position.v, {10, 5, 3, 1}, "=")
        ms(bunny.rotation.v, {0, -60, 0, 0}, "=")

        bunny.mesh.path = "bunny.mesh"
        component_util.load_mesh(bunny)

        bunny.material.content[1] = {path = "bunny.material", properties = {}}
        component_util.load_material(bunny)
    end

    do
        local sceneparser = require "modelloader.sceneparser"
        local path = require "filesystem.path"

        local scene_path = "D:/Engine/BnH/art/bnh/Assets/jingzhou/test_scene2.unity"
        local fbx_model_dir = "D:/Engine/BnH/art/bnh/Assets/jingzhou/fbx"

        local fbx_guid, prefab_objects, game_objects = sceneparser.Parse(scene_path, fbx_model_dir)

        for _, go in ipairs(game_objects) do
            local fbx_info = fbx_guid[go.mesh.guid]
            if fbx_info then
                local file_path = fbx_info.path
                ---[[
                local gameobj_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material", "name", "serialize", "can_select")

                local game_obj = world[gameobj_eid]
                game_obj.name.n = go.name
               -- print("create gameobject", go.name)
                ms(game_obj.scale.v, {go.local_scale[1]*0.01, go.local_scale[2]*0.01, go.local_scale[3]*0.01, 0}, "=")
                ms(game_obj.position.v, go.local_position, "=")
                ms(game_obj.rotation.v, go.local_rotation, "=")


                local file_name = path.filename_without_ext(file_path)
                game_obj.mesh.path = "test_scene/"..file_name..".mesh"
                local fileID = go.mesh.fileID
               -- if fbx_info.fileID[fileID] ~= "%/%/RootNode" then
              --      print("fileID", fileID, fbx_info.fileID[fileID])
              --  end
                component_util.load_mesh(game_obj)

                print("fffffff", game_obj.mesh.handle)
                game_obj.material.content[1] = {path = "fbxdefault.material", properties = {}}
                component_util.load_material(game_obj)
                --]]
            end
        end


        for _, prefab in ipairs(prefab_objects) do
            local fbx_info = fbx_guid[prefab.mesh.guid]
            if fbx_info then
                local file_path = fbx_info.path
                ---[[
                local prefabobj_eid = world:new_entity("position", "rotation", "scale",
                        "can_render", "mesh", "material", "name", "serialize", "can_select")

                local prefab_obj = world[prefabobj_eid]
                prefab_obj.name.n = prefab.name

                local file_name = path.filename_without_ext(file_path)
                prefab_obj.mesh.path = "test_scene/"..file_name..".mesh"
                local fileID = prefab.mesh.fileID
              --  print("fileID", fileID, fbx_info.fileID[fileID])
                component_util.load_mesh(prefab_obj)

                for k,v in pairs(prefab_obj.mesh.assetinfo.handle.group[1].prim[1]) do
                    print("sdfs", k, v)

                end


                ms(prefab_obj.scale.v, {prefab.local_scale[1]*0.01, prefab.local_scale[2]*0.01, prefab.local_scale[3]*0.01, 0}, "=")
                ms(prefab_obj.position.v, prefab.local_position, "=")
                ms(prefab_obj.rotation.v, prefab.local_rotation, "=")



                prefab_obj.material.content[1] = {path = "fbxdefault.material", properties = {}}
                component_util.load_material(prefab_obj)
                --]]
            end
        end


    end

    --[[
        do
            local stone_eid = world:new_entity("position", "rotation", "scale",
            "can_render", "mesh", "material",
            "name", "serialize", "can_select")

            local stone = world[stone_eid]
            stone.name.n = "texture_stone"

            mu.identify_transform(ms, stone)

            local function create_plane_mesh()
                local vdecl = bgfx.vertex_decl {
                    { "POSITION", 3, "FLOAT" },
                    { "NORMAL", 3, "FLOAT"},
                    { "TEXCOORD0", 2, "FLOAT"},
                }

                local lensize = 5

                return {
                    handle = {
                        group = {
                            {
                                vdecl = vdecl,
                                vb = bgfx.create_vertex_buffer(
                                    {"ffffffff",
                                lensize, -lensize, 0.0,
                                0.0, 0.0, -1.0,
                                1.0, 0.0,

                                lensize, lensize, 0.0,
                                0.0, 0.0, -1.0,
                                1.0, 1.0,

                                -lensize, -lensize, 0.0,
                                0.0, 0.0, -1.0,
                                0.0, 0.0,

                                -lensize, lensize, 0.0,
                                0.0, 0.0, -1.0,
                                0.0, 1.0,
                                }, vdecl)
                            },
                        }
                    }
                }
            end

            stone.mesh.path = ""	-- runtime mesh info
            stone.mesh.assetinfo = create_plane_mesh()


            stone.material.content[1] = {path = "stone.material", properties={}}
            component_util.load_material(stone)
        end
        --]]
    local function create_entity(name, meshfile, materialfile)
        local eid = world:new_entity("rotation", "position", "scale",
                "mesh", "material",
                "name", "serialize",
                "can_select", "can_render")

        local entity = world[eid]
        entity.name.n = name

        ms(entity.scale.v, {1, 1, 1}, "=")
        ms(entity.position.v, {0, 0, 0, 1}, "=")
        ms(entity.rotation.v, {0, 0, 0}, "=")

        entity.mesh.path = meshfile
        component_util.load_mesh(entity)
        entity.material.content[1] = {path=materialfile, properties={}}
        component_util.load_material(entity)
        return eid
    end

    do
        local hierarchy_eid = world:new_entity("editable_hierarchy", "hierarchy_name_mapper",
                "scale", "rotation", "position",
                "name", "serialize")
        local hierarchy_e = world[hierarchy_eid]

        hierarchy_e.name.n = "hierarchy_test"

        ms(hierarchy_e.scale.v, {1, 1, 1}, "=")
        ms(hierarchy_e.rotation.v, {0, 60, 0}, "=")
        ms(hierarchy_e.position.v, {10, 0, 0, 1}, "=")

        local hierarchy = hierarchy_e.editable_hierarchy.root

        hierarchy[1] = {
            name = "h1_cube",
            transform = {
                t = {3, 4, 5},
                s = {0.01, 0.01, 0.01},
            }
        }

        hierarchy[2] = {
            name = "h1_sphere",
            transform = {
                t = {1, 2, 3},
                s = {0.01, 0.01, 0.01},
            }
        }

        hierarchy[1][1] = {
            name = "h1_h1_cube",
            transform = {
                t = {3, 3, 3},
                s = {0.01, 0.01, 0.01},
            }
        }

        local material_path = "mem://hierarchy.material"
        fs_util.write_to_file(material_path, [[
			shader = {
				vs = "vs_mesh",
				fs = "fs_mesh",
			}
			state = "default.state"
			properties = {
				u_time = {name="u_time", type="v4", default={1, 0, 0, 1}}
			}
		]])

        local stone_eid = create_entity("h1_cube", "cube.mesh", material_path)
        local stone_eid_1 = create_entity("h1_h1_cube", "cube.mesh", material_path)
        do
            local e = world[stone_eid_1]
            ms(e.scale.v, {0.5, 0.5, 0.5}, "=")
        end

        local sphere_eid = create_entity("h1_sphere", "sphere.mesh", material_path)
        local name_mapper = assert(hierarchy_e.hierarchy_name_mapper.v)

        name_mapper.h1_cube     = stone_eid
        name_mapper.h1_h1_cube  = stone_eid_1
        name_mapper.h1_sphere   = sphere_eid

        world:change_component(hierarchy_eid, "rebuild_hierarchy")
        world:notify()
    end
end