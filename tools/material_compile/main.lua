package.path = "engine/?.lua"
require "bootstrap"

local function start(initargs)
    local task = dofile "/engine/task/bootstrap.lua"
    local exclusive = { "timer", "subprocess" }
    task {
        support_package = true,
        service_path = "${package}/service/?.lua",
        bootstrap = { "tools.material_compile|init", initargs },
        logger = { "logger" },
        exclusive = exclusive,
        debuglog = "log.txt",
    }
end

start(arg)