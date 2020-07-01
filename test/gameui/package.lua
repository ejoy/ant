return {
    name = "ant.test.gameui",
    ecs = {
        import = {
            "@ant.test.gameui",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.test.gameui|gameui",
        }
    }
}
