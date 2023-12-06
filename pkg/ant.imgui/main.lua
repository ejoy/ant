local function start(initargs)
    local task = dofile "/engine/task/bootstrap.lua"
    local exclusive = { {"ant.imgui|imgui", initargs}, "timer", "ant.hwi|bgfx" }
    if not __ANT_RUNTIME__ then
        exclusive[#exclusive+1] = "subprocess"
    end
    task {
        bootstrap = { "ant.imgui|boot" },
        logger = { "logger" },
        exclusive = exclusive,
        --debuglog = "log.txt",
    }
end

return {
    start = start,
}
