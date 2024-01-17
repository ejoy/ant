package.path = "/engine/?.lua"
require "bootstrap"

import_package "ant.window".start {
    feature = {
        "ant.test.rmlui",
        "ant.rmlui",
        "ant.pipeline",
    }
}
