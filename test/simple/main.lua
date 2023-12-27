package.path = "/engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    feature = {
        "ant.test.simple",
        "ant.render|render",
        "ant.animation",
        "ant.camera|camera_controller",
        "ant.sky|sky",
    },
}
