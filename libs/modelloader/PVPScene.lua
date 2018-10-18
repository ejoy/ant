local PVPScene = {}

function PVPScene.init(world, component_util, ms)

    --campsite door
    do
        local campsite_door_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_door = world[campsite_door_eid]
        campsite_door.name.n = "CampsiteDoor"

        ms(campsite_door.scale.v, {1, 1, 1}, "=")
        ms(campsite_door.rotation.v, {-90, -90, 0,}, "=")
        ms(campsite_door.position.v, {-12.95, 0.7867187, -14.03104}, "=")

        -- 加入阴影测试 
        component_util.load_mesh(campsite_door, "PVPScene/campsite-door.mesh")
        component_util.load_material(campsite_door, {"PVPScene/scene-mat-shadow.material"})

        local campsite_door_1_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_door_1 = world[campsite_door_1_eid]
        campsite_door_1.name.n = "CampsiteDoor_1"

        ms(campsite_door_1.scale.v, {1, 1, 1}, "=")
        ms(campsite_door_1.rotation.v, {-90, 90, 0,}, "=")
        ms(campsite_door_1.position.v, {124.35, 0.7867187, -14.03104}, "=")

        component_util.load_mesh(campsite_door_1, "PVPScene/campsite-door.mesh")
        component_util.load_material(campsite_door_1, {"PVPScene/scene-mat-shadow.material"})
    end

    --campsite wall
    do
        local campsite_wall_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_wall = world[campsite_wall_eid]
        campsite_wall.name.n = "CampsiteWall"

        ms(campsite_wall.scale.v, {1, 1, 1}, "=")
        ms(campsite_wall.rotation.v, {-90, 90, 0,}, "=")
        ms(campsite_wall.position.v, {-12.45, 0.7867187, -42.53104}, "=")

        component_util.load_mesh(campsite_wall, "PVPScene/campsite-wall.mesh")
        component_util.load_material(campsite_wall, {"PVPScene/scene-mat-shadow.material"})



        local campsite_wall_1_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_wall_1 = world[campsite_wall_1_eid]
        campsite_wall_1.name.n = "CampsiteWall_1"

        ms(campsite_wall_1.scale.v, {1, 1, 1}, "=")
        ms(campsite_wall_1.rotation.v, {-90, 90, 0,}, "=")
        ms(campsite_wall_1.position.v, {-12.45, 0.7867187, 14.06897}, "=")

        component_util.load_mesh(campsite_wall_1, "PVPScene/campsite-wall.mesh")
        component_util.load_material(campsite_wall_1, {"PVPScene/scene-mat-shadow.material"})



        local campsite_wall_4_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_wall_4 = world[campsite_wall_4_eid]
        campsite_wall_4.name.n = "CampsiteWall_4"

        ms(campsite_wall_4.scale.v, {1, 1, 1}, "=")
        ms(campsite_wall_4.rotation.v, {-90, 90, 0,}, "=")
        ms(campsite_wall_4.position.v, {124.85, 0.7867187, -56.8310}, "=")

        component_util.load_mesh(campsite_wall_4, "PVPScene/campsite-wall.mesh")
        component_util.load_material(campsite_wall_4, {"PVPScene/scene-mat-shadow.material"})



        local campsite_wall_5_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_wall_5 = world[campsite_wall_5_eid]
        campsite_wall_5.name.n = "CampsiteWall_5"

        ms(campsite_wall_5.scale.v, {1, 1, 1}, "=")
        ms(campsite_wall_5.rotation.v, {-90, 90, 0,}, "=")
        ms(campsite_wall_5.position.v, {124.85, 0.7867187, 28.36897}, "=")

        component_util.load_mesh(campsite_wall_5, "PVPScene/campsite-wall.mesh")
        component_util.load_material(campsite_wall_5, {"PVPScene/scene-mat-shadow.material"})



        local campsite_wall_6_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_wall_6 = world[campsite_wall_6_eid]
        campsite_wall_6.name.n = "CampsiteWall_6"

        ms(campsite_wall_6.scale.v, {1, 1, 1}, "=")
        ms(campsite_wall_6.rotation.v, {-90, 90, 0,}, "=")
        ms(campsite_wall_6.position.v, {124.85, 0.7867187, 14.06897}, "=")

        component_util.load_mesh(campsite_wall_6, "PVPScene/campsite-wall.mesh")
        component_util.load_material(campsite_wall_6, {"PVPScene/scene-mat-shadow.material"})




        local campsite_wall_7_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_wall_7 = world[campsite_wall_7_eid]
        campsite_wall_7.name.n = "CampsiteWall_7"

        ms(campsite_wall_7.scale.v, {1, 1, 1}, "=")
        ms(campsite_wall_7.rotation.v, {-90, 90, 0,}, "=")
        ms(campsite_wall_7.position.v, {124.85, 0.7867187, -42.5310}, "=")

        component_util.load_mesh(campsite_wall_7, "PVPScene/campsite-wall.mesh")
        component_util.load_material(campsite_wall_7, {"PVPScene/scene-mat-shadow.material"})
    end

    --campsite_jianta
    do
        local campsite_jianta_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_jianta = world[campsite_jianta_eid]
        campsite_jianta.name.n = "campsite_jianta"

        ms(campsite_jianta.scale.v, {0.5, 0.5, 0.5}, "=")
        ms(campsite_jianta.rotation.v, {-90, 0, 0,}, "=")
        ms(campsite_jianta.position.v, {7.0, 0.96, -14.03104}, "=")

        component_util.load_mesh(campsite_jianta, "PVPScene/campsite-door-01.mesh")
        component_util.load_material(campsite_jianta, {"PVPScene/scene-mat-shadow.material"})



        local campsite_jianta_1_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_jianta_1 = world[campsite_jianta_1_eid]
        campsite_jianta_1.name.n = "campsite_jianta_1"

        ms(campsite_jianta_1.scale.v, {0.5, 0.5, 0.5}, "=")
        ms(campsite_jianta_1.rotation.v, {-90, 0, 0,}, "=")
        ms(campsite_jianta_1.position.v, {27.0, 0.96, -14.03104}, "=")

        component_util.load_mesh(campsite_jianta_1, "PVPScene/campsite-door-01.mesh")
        component_util.load_material(campsite_jianta_1, {"PVPScene/scene-mat-shadow.material"})



        local campsite_jianta_2_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_jianta_2 = world[campsite_jianta_2_eid]
        campsite_jianta_2.name.n = "campsite_jianta_2"

        ms(campsite_jianta_2.scale.v, {0.5, 0.5, 0.5}, "=")
        ms(campsite_jianta_2.rotation.v, {-90, 0, 0,}, "=")
        ms(campsite_jianta_2.position.v, {104.4, 0.96, -14.03104}, "=")

        component_util.load_mesh(campsite_jianta_2, "PVPScene/campsite-door-01.mesh")
        component_util.load_material(campsite_jianta_2, {"PVPScene/scene-mat-shadow.material"})



        local campsite_jianta_3_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local campsite_jianta_3 = world[campsite_jianta_3_eid]
        campsite_jianta_3.name.n = "campsite_jianta_3"

        ms(campsite_jianta_3.scale.v, {0.5, 0.5, 0.5}, "=")
        ms(campsite_jianta_3.rotation.v, {-90, 0, 0,}, "=")
        ms(campsite_jianta_3.position.v, {84.4, 0.96, -14.03104}, "=")

        component_util.load_mesh(campsite_jianta_3, "PVPScene/campsite-door-01.mesh")
        component_util.load_material(campsite_jianta_3, {"PVPScene/scene-mat-shadow.material"})
    end

    --fuhuodianA tent
    local fuhuodianA_position = {-21.07, 5.218985, -8.18463}
    local fuhuodianA_rotation = {0, 180, 0}
    do
        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90, 90, 0}, fuhuodianA_rotation, "+=")
            ms(tent.position.v, {-0.23547, -6.418437, -19.0813}, fuhuodianA_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90, 90, 0}, fuhuodianA_rotation, "+=")
            ms(tent.position.v, {8.035471, -6.418437, -19.0813}, fuhuodianA_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-89.98, 0, 47.621}, fuhuodianA_rotation, "+=")
            ms(tent.position.v, {5.804538, -6.418437, -10.04131}, fuhuodianA_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90.0, 0, 0}, fuhuodianA_rotation, "+=")
            ms(tent.position.v, {4.444535, -6.418437, -1.84131}, fuhuodianA_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90.0, 0, 0}, fuhuodianA_rotation, "+=")
            ms(tent.position.v, {4.444535, -6.418437, 6.4487}, fuhuodianA_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90.0, -35.40240, 0}, fuhuodianA_rotation, "+=")
            ms(tent.position.v, {-1.835464, -6.418437, 6.368698}, fuhuodianA_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90.0, -91.4971, 0}, fuhuodianA_rotation, "+=")
            ms(tent.position.v, {-10.1, -6.418437, 6.2}, fuhuodianA_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90.0, -91.4971, 0}, fuhuodianA_rotation, "+=")
            ms(tent.position.v, {-18.14546, -6.418437, 5.858704}, fuhuodianA_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end
    end

    --fuhuodianB tent
    do
        local fuhuodianB_position = {134.72, 5.218985, 17.32593}

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90.0, 90.0, 0}, "=")
            ms(tent.position.v, {-10.14546, -6.418437, -19.0813}, fuhuodianB_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90.0, 90.0, 0}, "=")
            ms(tent.position.v, {-2.935471, -6.418437, -19.0813}, fuhuodianB_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90.0, -91.4971, 0}, "=")
            ms(tent.position.v, {6.64546, -6.418437, -42.858704}, fuhuodianB_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90.0, -91.4971, 0}, "=")
            ms(tent.position.v, {14.56548, -6.418437, -42.858704}, fuhuodianB_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end


        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-89.98, 0.0, 47.621}, "=")
            ms(tent.position.v, {-10.104538, -6.418437, -28.54131}, fuhuodianB_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90, -35.4024, 0}, "=")
            ms(tent.position.v, {-1.835464, -6.418437, -44.368698}, fuhuodianB_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90, 0.0, 0}, "=")
            ms(tent.position.v, {-9.944534, -6.418437, -43.341309}, fuhuodianB_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end

        do
            local tent_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local tent = world[tent_eid]
            tent.name.n = "tent"

            ms(tent.scale.v, {1, 1, 1}, "=")
            ms(tent.rotation.v, {-90, 0.0, 0}, "=")
            ms(tent.position.v, {-9.944534, -6.418437, -36.9487}, fuhuodianB_position, "+=")

            component_util.load_mesh(tent, "PVPScene/tent-06.mesh")
            component_util.load_material(tent, {"PVPScene/tent-shadow.material"})
        end
    end

    -- other stuff
    do
        local wood_build_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local wood_build = world[wood_build_eid]
        wood_build.name.n = "wood_build"

        ms(wood_build.scale.v, {1, 1, 1}, "=")
        ms(wood_build.rotation.v, {-90, -90.7483, 0}, "=")
        --ms(wood_build.position.v, {37.152405, -0.429453, 5.41463}, "=")
        ms(wood_build.position.v, { 30.41463 , 1.72, 7.152405 }, "=")

        component_util.load_mesh(wood_build, "PVPScene/woodbuilding-05.mesh")
        component_util.load_material(wood_build, {"PVPScene/scene-mat-shadow.material"})


        local woodother_46_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local woodother_46 = world[woodother_46_eid]
        woodother_46.name.n = "woodother_46"

        ms(woodother_46.scale.v, {1, 1, 1}, "=")
        ms(woodother_46.rotation.v, {-90, -108.1401, 0}, "=")
        ms(woodother_46.position.v, {33.882416, 0.149453, -32.164627}, "=")

        component_util.load_mesh(woodother_46, "PVPScene/woodother-46.mesh")
        component_util.load_material(woodother_46, {"PVPScene/scene-mat-shadow.material"})


        local woodother_46_1_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local woodother_46_1 = world[woodother_46_1_eid]
        woodother_46_1.name.n = "woodother_46_1"

        ms(woodother_46_1.scale.v, {1, 1, 1}, "=")
        ms(woodother_46_1.rotation.v, {-90, -108.1401, 0}, "=")
        ms(woodother_46_1.position.v, {115.39, 0.149453, -27.164627}, "=")

        component_util.load_mesh(woodother_46_1, "PVPScene/woodother-46.mesh")
        component_util.load_material(woodother_46_1, {"PVPScene/scene-mat-shadow.material"})


        local woodother_45_eid = world:new_entity("position", "rotation", "scale",
                "can_render", "mesh", "material",
                "name", "serialize",
                "can_select")
        local woodother_45 = world[woodother_45_eid]
        woodother_45.name.n = "woodother_45"

        ms(woodother_45.scale.v, {1, 1, 1}, "=")
        ms(woodother_45.rotation.v, {-90, 50.3198, 0}, "=")
        ms(woodother_45.position.v, {-28.68, 2, -10.164627}, "=")

        component_util.load_mesh(woodother_45, "PVPScene/woodother-45.mesh")
        component_util.load_material(woodother_45, {"PVPScene/scene-mat-shadow.material"})


        --woodother 34
        local woodother_34_position = {-2.1949, 1.842032, -39.867749}
        do
            local woodother_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local woodother_34 = world[woodother_eid]
            woodother_34.name.n = "woodother_34"

            ms(woodother_34.scale.v, {1, 1, 1}, "=")
            ms(woodother_34.rotation.v, {-90, 0, 20}, "=")
            ms(woodother_34.position.v, {120, -1.741485, 34.06}, woodother_34_position,"+=")

            component_util.load_mesh(woodother_34, "PVPScene/woodother-34.mesh")
            component_util.load_material(woodother_34, {"PVPScene/scene-mat-shadow.material"})

        end

        do
            local woodother_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local woodother_34 = world[woodother_eid]
            woodother_34.name.n = "woodother_34"

            ms(woodother_34.scale.v, {1, 1, 1}, "=")
            ms(woodother_34.rotation.v, {-90, 0, 0}, "=")
            ms(woodother_34.position.v, {116, -1.741485, 36.06}, woodother_34_position,"+=")

            component_util.load_mesh(woodother_34, "PVPScene/woodother-34.mesh")
            component_util.load_material(woodother_34, {"PVPScene/scene-mat-shadow.material"})
        end

        do
            local woodother_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local woodother_34 = world[woodother_eid]
            woodother_34.name.n = "woodother_34"

            ms(woodother_34.scale.v, {1, 1, 1}, "=")
            ms(woodother_34.rotation.v, {-90, 0, 20}, "=")
            ms(woodother_34.position.v, {102.1759, -1.741485, 36.53}, woodother_34_position,"+=")

            component_util.load_mesh(woodother_34, "PVPScene/woodother-34.mesh")
            component_util.load_material(woodother_34, {"PVPScene/scene-mat-shadow.material"})
        end

        do
            local woodother_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local woodother_34 = world[woodother_eid]
            woodother_34.name.n = "woodother_34"

            ms(woodother_34.scale.v, {1, 1, 1}, "=")
            ms(woodother_34.rotation.v, {-90, 0, 0}, "=")
            ms(woodother_34.position.v, {98.1759, -1.741485, 36.08}, woodother_34_position,"+=")

            component_util.load_mesh(woodother_34, "PVPScene/woodother-34.mesh")
            component_util.load_material(woodother_34, {"PVPScene/scene-mat-shadow.material"})
        end

        do
            local woodother_eid = world:new_entity("position", "rotation", "scale",
                    "can_render", "mesh", "material",
                    "name", "serialize",
                    "can_select")
            local woodother_34 = world[woodother_eid]
            woodother_34.name.n = "woodother_34"

            ms(woodother_34.scale.v, {1, 1, 1}, "=")
            ms(woodother_34.rotation.v, {-90, -60, 0}, "=")
            ms(woodother_34.position.v, {132.85, -1.741485, 33.62238}, woodother_34_position,"+=")

            component_util.load_mesh(woodother_34, "PVPScene/woodother-34.mesh")
            component_util.load_material(woodother_34, {"PVPScene/scene-mat-shadow.material"})
        end
    end
end

return PVPScene