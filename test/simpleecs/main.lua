package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.test.simpleecs",
    },
    system = {
        "ant.test.simpleecs|init_system",
    },
}
