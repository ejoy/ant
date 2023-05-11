package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
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
    },
    interface = {
    },
    policy = {
    }
}
