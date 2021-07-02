local function start(packagename)
    local task = dofile "engine/task/bootstrap.lua"
    task {
        service_path = "/pkg/ant.window/service/?.lua;/pkg/ant.render/service/?.lua;/pkg/ant.rmlui/service/?.lua",
        bootstrap = { "boot", packagename },
        logger = { "logger" },
        exclusive = { "window", "timer", "bgfx_main" },
        --debuglog = "log.txt",
    }
end

return {
    start = start,
}
