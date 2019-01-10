local pkg = {}
for _, name in ipairs {
	"addressnavigation_ctrl",
	"assetprobe",
	"assetview",
	"hierarchyview",
	"listctrl",
	"matrixview",
	"popupmenu",
	"propertyview",
	"tree",
	"vectorview",
	"util",	
} do
	pkg[name] = require(name)
end

pkg["logview"] = require "log.logview"
pkg.common = {
	observer = require "common.observer",
}

return pkg