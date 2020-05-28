return {
    name = "ant.test.simple",
    ecs = {
        import = {
            "@ant.test.simple",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.test.simple|init_system",
        }
    }
}
