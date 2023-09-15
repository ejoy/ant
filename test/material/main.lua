package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.render",
    },
    feature = {
        "ant.test.material",
        "ant.camera|camera_controller",
        "ant.sky|sky",
    },
    policy = {
        "ant.render|render",
        "ant.render|render_queue",
    }
}
