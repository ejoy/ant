package.path = "/engine/?.lua"
require "bootstrap"

import_package "ant.window".start {
    feature = {
        "ant.test.httpc",
        "ant.render",
        "ant.shadow_bounding|scene_bounding",
        "ant.pipeline"
    }
}
