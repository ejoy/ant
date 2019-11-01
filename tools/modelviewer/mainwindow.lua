local packages = {
	"ant.modelviewer"
}
local systems = {
	"model_review_system",
}

local runtime = import_package "ant.imguibase".runtime
local fs 		= require "filesystem"
runtime.start(packages, systems, fs.path "/pkg/ant.modelviewer/settings")
