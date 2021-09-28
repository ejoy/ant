local function start(packagename, w, h)
    local task = dofile "/engine/task/bootstrap.lua"
    task {
        support_package = true,
        service_path = "${package}/service/?.lua",
        bootstrap = { "ant.imgui|boot" },
        logger = { "logger" },
        exclusive = { {"ant.imgui|imgui", packagename, w, h}, "timer", "ant.render|bgfx_main" },
        --debuglog = "log.txt",
    }
end

return {
    start = start,
}
