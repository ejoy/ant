import_package "ant.window".start {
    --window_size = "1280x720",
	cmd = ...,
    feature = {
        "ant.render",
        "ant.test.features",
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
