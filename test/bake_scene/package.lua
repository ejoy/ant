return {
    name = "ant.test.bake_scene",
    ecs = {
        import = {
            "@ant.test.bake_scene",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.test.bake_scene|init_system",
        }
    },
}
