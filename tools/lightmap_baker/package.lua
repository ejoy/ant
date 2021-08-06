return {
    name = "ant.tool.lightmap_baker",
    ecs = {
        import = {
            "@ant.tool.lightmap_baker",
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "ant.tool.lightmap_baker|lightmap_baker_system",
        }
    }
}