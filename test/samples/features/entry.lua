local packages = {
	"ant.test.features"
}
local systems = {
	"init_loader",
	"scenespace_test",
	"terrain_test",
    "visible_system",
}

local runtime = import_package "ant.imgui".runtime
runtime.start(packages, systems)
