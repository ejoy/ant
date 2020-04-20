return {
    name = "ant.test.animation",
    ecs = {
        import = {
            "@ant.test.animation",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.test.animation|init_loader_system",
        }
    }
}
