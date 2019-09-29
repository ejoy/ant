local packages = {
	"bloom"
}
local systems = {
    "pbr_bloom_demo",
    --"bloom_sys",
}

local runtime = import_package "ant.imguibase".runtime
runtime.start(packages, systems)
