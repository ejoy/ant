return {
    name = "ant.test.simple",
    ecs = {
        import = {
            "@ant.test.simple",
            "@ant.objcontroller",
            "@ant.animation",
            "@ant.effekseer",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.test.simple|init_system",
        },
        interface = {
            "ant.objcontroller|obj_motion",
            "ant.animation|animation",
            --"ant.effekseer|effekseer_playback",
        },
        policy_v2 = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.scene|scene_node",
            "ant.render|render",
            "ant.render|render_queue",
            "ant.objcontroller|pickup",
        }
    }
}
