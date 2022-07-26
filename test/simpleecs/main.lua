package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.test.simpleecs",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
    system = {
        "ant.test.simpleecs|init_system",
    },
}
