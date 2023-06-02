return {
    name = "ant.compile_resource",
    entry = "main",
    dependencies = {
        "ant.json",
        "ant.serialize",
        "ant.settings",
        "ant.subprocess",
    }
}
