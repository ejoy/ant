package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.test.material",
    },
    feature = {
        "ant.camera|camera_controller",
        "ant.sky|sky",
    },
    system = {
        "ant.test.material|init_system",
    },
    policy = {
        "ant.render|render",
        "ant.render|render_queue",
    }
}
