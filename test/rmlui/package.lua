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
        }
    }
}
