return {
    name = "ant.test.features",
    world = {
        policy = {
            "ant.animation|animation",
            "ant.animation|animation_controller.state_machine",
            "ant.animation|animation_controller.birth",
            "ant.animation|ozzmesh",
            "ant.animation|ozz_skinning",
            "ant.animation|skinning",
            "ant.animation|ik",
            "ant.serialize|serialize",
            "ant.collision|collider",
            "ant.sky|procedural_sky",
            "ant.render|name",
            "ant.render|mesh",
            "ant.render|shadow_cast",
            "ant.render|render",
            "ant.render|bounding_draw",
            "ant.render|debug_mesh_bounding",
            "ant.render|light.directional",
            "ant.render|light.ambient",
            "ant.scene|hierarchy",
            --editor
            "ant.character|character",
            "ant.objcontroller|select",
        },
        system = {
            "ant.test.features|init_loader",
        },
    }
}
