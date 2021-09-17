local function start(initargs)
    local task = dofile "engine/task/bootstrap.lua"
    task {
        support_package = true,
        service_path = "${package}/service/?.lua",
        bootstrap = { "ant.window|boot", initargs },
        logger = { "logger" },
        exclusive = { "ant.window|window", "timer", "ant.render|bgfx_main" },
        --debuglog = "log.txt",
    }
end

return {
    start = start,
}
