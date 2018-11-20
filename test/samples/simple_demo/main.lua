package.path = "engine/libs/?.lua;engine/libs/?/?.lua;?.lua"

local rt = require "runtime"
rt.start {
	"modelloader.renderworld",
	"modelloader.camera_controller",
}
