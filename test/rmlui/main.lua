package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.test.rmlui",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
    system = {
        "ant.test.rmlui|init_system",
    },
    policy_v2 = {
        "ant.general|name",
        "ant.scene|scene_object",
        "ant.render|render",
        "ant.render|render_queue",
    }
}
