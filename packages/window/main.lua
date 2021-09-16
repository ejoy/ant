local function start(packagename)
    local task = dofile "engine/task/bootstrap.lua"
    task {
        service_path = "${package}/service/?.lua",
        bootstrap = { "ant.window|boot", packagename },
        logger = { "logger" },
        exclusive = { "ant.window|window", "timer", "ant.render|bgfx_main" },
        --debuglog = "log.txt",
    }
end

return {
    start = start,
}
