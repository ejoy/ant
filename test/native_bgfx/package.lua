return {
    name = "ant.test.native_bgfx",
    ecs = {
        import = {
            "@ant.test.native_bgfx",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.test.native_bgfx|init_system",
        }
    }
}
