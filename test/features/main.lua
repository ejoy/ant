package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
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
