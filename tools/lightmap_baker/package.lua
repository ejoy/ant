return {
    name = "ant.test.ibl",
    ecs = {
        import = {
            "@ant.test.ibl",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.test.ibl|init_system",
        }
    }
}