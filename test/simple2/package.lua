return {
    name = "ant.test.simple2",
    ecs = {
        import = {
            "@ant.test.simple2",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.test.simple2|init_system",
        }
    }
}
