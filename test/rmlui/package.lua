return {
    name = "ant.test.rmlui",
    ecs = {
        import = {
            "@ant.test.rmlui",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.test.rmlui|init_system",
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
