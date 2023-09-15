package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.test.native_bgfx",
    },
    system = {
        "ant.test.native_bgfx|init_system",
    }
}
