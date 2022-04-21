package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.test.simple",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
    system = {
        "ant.test.simple|init_system",
    },
    interface = {
        "ant.objcontroller|iobj_motion",
        "ant.animation|ianimation",
    },
    policy = {
        "ant.general|name",
        "ant.scene|scene_object",
        "ant.render|render",
        "ant.render|render_queue",
        "ant.objcontroller|pickup",
    }
}
