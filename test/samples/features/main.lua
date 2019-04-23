local packages = {
	"ant.test.features"
}
local systems = {
	"init_loader",
	"scenespace_test",
	"terrain_test",	
}

if __ANT_RUNTIME__ then
	local rt = require "runtime"
	rt.start(packages, systems)
	return
end
