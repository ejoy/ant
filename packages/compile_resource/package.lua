return {
    name = "ant.compile_resource",
    entry = "main",
    dependencies = {
        "ant.url",
        "ant.json",
        "ant.render",
        "ant.serialize",
        "ant.settings",
        "ant.subprocess",
    }
}
