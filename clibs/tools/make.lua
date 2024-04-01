local lm = require "luamake"

lm:copy "tools_version" {
	inputs = "version",
	outputs = "$bin/tools_version",
}
