return {
    name = "ant.test.features",
    ecs = {
        import = {
            "@ant.test.features",
        },
        system = {
            "ant.test.features|init_loader_system",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        policy = {},
    }
}
