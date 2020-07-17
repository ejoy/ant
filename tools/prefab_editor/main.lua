package.path = table.concat({
	"engine/?.lua",
	"engine/?/?.lua",
	"?.lua",
}, ";")

require "bootstrap"
--import_package "ant.imguibase".runtime.start("ant.tools.prefab_editor", 1280, 720)
import_package "tools.prefab_editor.editor"