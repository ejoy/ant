local function start(packagename, w, h)
    local task = dofile "engine/task/bootstrap.lua"
    task {
        service_path = "/pkg/ant.imgui/service/?.lua;/pkg/ant.render/service/?.lua;/pkg/ant.rmlui/service/?.lua",
        bootstrap = { "boot" },
        logger = { "logger" },
        exclusive = { {"imgui", packagename, w, h}, "timer" },
        --debuglog = "log.txt",
    }
end

return {
    start = start,
}
