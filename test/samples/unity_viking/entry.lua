local packages = {
	"unity_viking"
}
local systems = {
	"scene_walker",
}

local runtime = import_package "ant.imguibase".runtime
runtime.start(packages, systems)
