
return {
    name = "ant.modelviewer",
    ecs = {
        policy = {
            -- "ant.animation|animation",
            -- "ant.animation|animation_controller.state_machine",
            -- "ant.animation|animation_controller.birth",
            -- "ant.animation|ozzmesh",
            -- "ant.animation|ozz_skinning",
            -- "ant.animation|skinning",
            -- "ant.animation|ik",
            -- "ant.collision|collider_policy",
            -- "ant.sky|procedural_sky",
            -- "ant.general|name",
            -- "ant.render|shadow_cast_policy",
            -- "ant.render|render",
            -- "ant.render|bounding_draw",
            -- "ant.render|debug_mesh_bounding",
            -- "ant.render|light.directional",
            -- "ant.render|light.ambient",
            -- "ant.scene|hierarchy_policy",
            -- --editor
            -- "ant.character|character",
            -- "ant.objcontroller|select",
        },
        import = {
            "@ant.modelviewer"
        },
        system = {
            "ant.modelviewer|model_viewer_system",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
    }
}