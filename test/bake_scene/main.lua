package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.test.bake_scene",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
    feature = {
        "ant.camera|camera_controller",
        "ant.sky|sky",
    },
    system = {
        "ant.test.bake_scene|init_system",
    }
}
