package.path = "/engine/?.lua"
require "bootstrap"

import_package "ant.window".start {
    feature = {
        "ant.test.rmlui",
        "ant.rmlui",
        "ant.render",
        "ant.shadow_bounding|scene_bounding",
        "ant.pipeline",
    }
}
