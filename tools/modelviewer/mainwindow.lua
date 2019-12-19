local packages = {
	"ant.modelviewer"
}
local systems = {
	"model_review_system",
}

local runtime = import_package "ant.imguibase".runtime
runtime.start(packages, systems)
