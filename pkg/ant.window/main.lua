local function start(initargs)
    local task = dofile "/engine/task/bootstrap.lua"
    local exclusive = { "ant.window|window", "timer", "ant.render|bgfx_main" }
    if not __ANT_RUNTIME__ then
        exclusive[#exclusive+1] = "subprocess"
    end
    task {
        support_package = true,
        service_path = "${package}/service/?.lua",
        bootstrap = { "ant.window|boot", initargs },
        logger = { "logger" },
        exclusive = exclusive,
        debuglog = "log.txt",
    }
end

return {
    start = start,
}
