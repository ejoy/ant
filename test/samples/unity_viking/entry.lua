local packages = {
	"unity_viking"
}
local systems = {
	"scene_walker",
}

local runtime = import_package "ant.imgui".runtime
runtime.start(packages, systems)
