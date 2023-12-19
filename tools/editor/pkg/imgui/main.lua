local function start(initargs)
    local task = dofile "/engine/task/bootstrap.lua"
    local exclusive = { {"imgui|imgui", initargs}, "timer", "ant.hwi|bgfx" }
    if not __ANT_RUNTIME__ then
        exclusive[#exclusive+1] = "subprocess"
    end
    task {
        bootstrap = { "imgui|boot" },
        logger = { "logger" },
        exclusive = exclusive,
        --debuglog = "log.txt",
    }
end

return {
    start = start,
}
