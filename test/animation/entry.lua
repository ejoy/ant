local packages = {
	"ant.test.animation"
}
local systems = {
	"init_loader",
}

local runtime = import_package "ant.imguibase".runtime
runtime.start(packages, systems)
