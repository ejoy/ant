package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.render",
    },
    feature = {
        "ant.test.bake_scene",
        "ant.camera|camera_controller",
        "ant.sky|sky",
    }
}
