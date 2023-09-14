package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    import = {
        "@ant.test.features",
    },
    feature = {
        "ant.sky|sky",
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
