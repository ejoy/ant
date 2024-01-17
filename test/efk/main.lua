package.path = "/engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    feature = {
        "ant.render|render",
        "ant.animation",
        "ant.test.efk",
        "ant.camera|camera_controller",
        "ant.efk",
        "ant.pipeline",
        "ant.sky|sky",
    }
}
