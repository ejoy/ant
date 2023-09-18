package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    feature = {
        "ant.test.material",
        "ant.camera|camera_controller",
        "ant.render",
        "ant.sky|sky",
    }
}
