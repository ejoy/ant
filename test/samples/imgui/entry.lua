local packages = {
	"ant.ImguiSample"
}
local systems = {
	"imgui_system",
}

local runtime = import_package "ant.imguibase".runtime
runtime.start(packages, systems)
