local packages = {
	"ant.test.features"
}
local systems = {
	"init_loader",
	"scenespace_test",
    "visible_system",
}

local runtime = import_package "ant.imguibase".runtime
runtime.start(packages, systems)
