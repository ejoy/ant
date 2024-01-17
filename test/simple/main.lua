package.path = "/engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    feature = {
        "ant.test.simple",
        "ant.render",
        "ant.animation",
        "ant.camera|camera_controller",
        "ant.shadow_bounding|scene_bounding",
        "ant.imgui",
        "ant.pipeline",
        "ant.sky|sky",
    },
}
