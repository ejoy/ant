package.path = "/engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    window_size = "1280x720",
    enable_mouse = true,
    feature = {
        "ant.render",
        "ant.test.features",
        "ant.anim_ctrl",
        "ant.animation",
        "ant.camera|camera_controller",
        "ant.camera|camera_recorder",
        "ant.daynight",
        "ant.motion_sampler",
        "ant.objcontroller|screen_3dobj",
        "ant.sky|sky",
        "ant.sky|procedural_sky",
        "ant.splitviews",
        "ant.terrain|canvas",
        "ant.terrain|water",
        "ant.imgui",
        "ant.pipeline",
    }
}
