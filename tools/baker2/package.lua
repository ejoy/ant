return {
    name = "ant.tool.baker",
    --entry = "bake",
    ecs = {
        import = {
            "@ant.tool.baker",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.tool.baker|init_system",
        }
    },
}
