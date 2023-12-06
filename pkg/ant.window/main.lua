local function start(initargs)
    local task = dofile "/engine/task/bootstrap.lua"
    local exclusive = { "ant.window|window", "timer", "ant.hwi|bgfx" }
    if not __ANT_RUNTIME__ then
        exclusive[#exclusive+1] = "subprocess"
    end
	local directory = require "directory"
	local log_path = directory.app_path()
    task {
        bootstrap = { "ant.window|boot", initargs },
        logger = { "logger" },
        exclusive = exclusive,
        debuglog = (log_path / "debug.log"):string(),
        crashlog = (log_path / "crash.log"):string(),
        worker = 4,
    }
end

local function reboot(initargs)
    local ltask = require "ltask"
    local ServiceWorld = ltask.queryservice "ant.window|world"
    ltask.send(ServiceWorld, "reboot", initargs)
end

return {
    start = start,
    reboot = reboot,
}
