local ecs = ...
local world = ecs.world
local w = world.w

local mathpkg       = import_package "ant.math"
local mc            = mathpkg.constant
local assetmgr      = import_package "ant.asset"
local window        = import_package "ant.window"
local irq           = ecs.require "ant.render|renderqueue"
local icamera       = ecs.require "ant.camera|camera"
local iom           = ecs.require "ant.objcontroller|obj_motion"
local editor_setting= require "editor_setting"
local ImGuiAnt      = import_package "ant.imgui"
local sys 			= require "bee.sys"
local global_data	= require "common.global_data"
local icons         = require "common.icons"
local math3d        = require "math3d"
local log_widget        = require "widget.log"
local console_widget    = require "widget.console"
local widget_utils      = require "widget.utils"

local m = ecs.system 'init_system'

local function start_fileserver(luaexe, path)
	local fsa = require "fileserver_adapter"
	fsa.init(luaexe, path)
	global_data.fileserver = fsa
end

local function init_font()
	local fonts = {}
	fonts[#fonts+1] = {
		FontPath = "/pkg/ant.resources.binary/font/Alibaba-PuHuiTi-Regular.ttf",
		SizePixels = 18,
		GlyphRanges = { 0x0020, 0xFFFF }
	}
	fonts[#fonts+1] = {
		FontPath = "/pkg/tools.editor/resource/fonts/fa-solid-900.ttf",
		SizePixels = 16,
		GlyphRanges = {
			0xf062, 0xf062, -- ICON_FA_ARROW_UP 			"\xef\x81\xa2"	U+f062
			0xf063, 0xf063,	-- ICON_FA_ARROW_DOWN 			"\xef\x81\xa3"	U+f063
			0xf0c7, 0xf0c7,	-- ICON_FA_FLOPPY_DISK 			"\xef\x83\x87"	U+f0c7
			0xf04b, 0xf04b, -- ICON_FA_PLAY 				"\xef\x81\x8b"	U+f04b
			0xf04d, 0xf04d, -- ICON_FA_STOP 				"\xef\x81\x8d"	U+f04d
			0xf14a, 0xf14a, -- ICON_FA_SQUARE_CHECK 		"\xef\x85\x8a"	U+f14a
			0xf2d3, 0xf2d3, -- ICON_FA_SQUARE_XMARK 		"\xef\x8b\x93"	U+f2d3
			0xf05e, 0xf05e, -- ICON_FA_BAN 					"\xef\x81\x9e"	U+f05e
			0xf1f8, 0xf1f8, -- ICON_FA_TRASH 				"\xef\x87\xb8"	U+f1f8
			0xf2ed, 0xf2ed, -- ICON_FA_TRASH_CAN 			"\xef\x8b\xad"	U+f2ed
			0xf28b, 0xf28b, -- ICON_FA_CIRCLE_PAUSE 		"\xef\x8a\x8b"	U+f28b
			0xf144, 0xf144, -- ICON_FA_CIRCLE_PLAY 			"\xef\x85\x84"	U+f144
			0xf28d, 0xf28d, -- ICON_FA_CIRCLE_STOP 			"\xef\x8a\x8d"	U+f28d
			0xf0fe, 0xf0fe, -- ICON_FA_SQUARE_PLUS 			"\xef\x83\xbe"	U+f0fe
			0xf0e2, 0xf0e2, -- ICON_FA_ARROW_ROTATE_LEFT 	"\xef\x83\xa2"	U+f0e2
			0xf01e, 0xf01e, -- ICON_FA_ARROW_ROTATE_RIGHT 	"\xef\x80\x9e"	U+f01e
			0xf002, 0xf002, -- ICON_FA_MAGNIFYING_GLASS 	"\xef\x80\x82"	U+f002
			0xf07b, 0xf07b, -- ICON_FA_FOLDER 				"\xef\x81\xbb"	U+f07b
			0xf07c, 0xf07c, -- ICON_FA_FOLDER_OPEN 			"\xef\x81\xbc"	U+f07c
			0xe4c2, 0xe4c2, -- ICON_FA_ARROWS_UP_TO_LINE 	"\xee\x93\x82"	U+e4c2
			0xe4b8, 0xe4b8, -- ICON_FA_ARROWS_DOWN_TO_LINE  "\xee\x92\xb8"	U+e4b8
			0xf65e, 0xf65e, -- ICON_FA_FOLDER_PLUS 			"\xef\x99\x9e"	U+f65e
			0xf65d, 0xf65d, -- ICON_FA_FOLDER_MINUS 		"\xef\x99\x9d"	U+f65d
			0xf24d, 0xf24d, -- ICON_FA_CLONE 				"\xef\x89\x8d"	U+f24d
			0xf068, 0xf068, -- ICON_FA_MINUS 				"\xef\x81\xa8"	U+f068
			0xf019, 0xf019, -- ICON_FA_DOWNLOAD 			"\xef\x80\x99"	U+f019
			0xf00d, 0xf00d, -- ICON_FA_XMARK 				"\xef\x80\x8d"	U+f00d
			0xf013, 0xf013, -- ICON_FA_GEAR 				"\xef\x80\x93"	U+f013
			0xf085, 0xf085, -- ICON_FA_GEARS 				"\xef\x82\x85"	U+f085
			0xf15b, 0xf15b, -- ICON_FA_FILE 				"\xef\x85\x9b"	U+f15b
			0xf31c, 0xf31c, -- ICON_FA_FILE_PEN 			"\xef\x8c\x9c"	U+f31c
			0xf304, 0xf304, -- ICON_FA_PEN 					"\xef\x8c\x84"	U+f304
			0xf0eb, 0xf0eb, -- ICON_FA_LIGHTBULB 			"\xef\x83\xab"	U+f0eb
			0xf03a, 0xf03a, -- ICON_FA_LIST 				"\xef\x80\xba"	U+f03a
			0xf023, 0xf023, -- ICON_FA_LOCK 				"\xef\x80\xa3"	U+f023
			0xf3c1, 0xf3c1, -- ICON_FA_LOCK_OPEN 			"\xef\x8f\x81"	U+f3c1
			0xf06e, 0xf06e, -- ICON_FA_EYE 					"\xef\x81\xae"	U+f06e
			0xf070, 0xf070, -- ICON_FA_EYE_SLASH 			"\xef\x81\xb0"	U+f070
			0xf00c, 0xf00c, -- ICON_FA_CHECK 				"\xef\x80\x8c"	U+f00c
			0xf058, 0xf058, -- ICON_FA_CIRCLE_CHECK 		"\xef\x81\x98"	U+f058
			0xf056, 0xf056, -- ICON_FA_CIRCLE_MINUS 		"\xef\x81\x96"	U+f056
			0xf055, 0xf055, -- ICON_FA_CIRCLE_PLUS 			"\xef\x81\x95"	U+f055
			0xf120, 0xf120, -- ICON_FA_TERMINAL 			"\xef\x84\xa0"	U+f120
			0xf05a, 0xf05a, -- ICON_FA_CIRCLE_INFO 			"\xef\x81\x9a"	U+f05a
			0xf35d, 0xf35d, -- ICON_FA_UP_RIGHT_FROM_SQUARE "\xef\x8d\x9d"	U+f35d
			0xf071, 0xf071, -- ICON_FA_TRIANGLE_EXCLAMATION "\xef\x81\xb1"	U+f071
			0xf1c6, 0xf1c6, -- ICON_FA_FILE_ZIPPER 			"\xef\x87\x86"	U+f1c6
			0xf245, 0xf245, -- ICON_FA_ARROW_POINTER 				"\xef\x89\x85" U+f245
			0xf047, 0xf047, -- ICON_FA_ARROWS_UP_DOWN_LEFT_RIGHT	"\xef\x81\x87" U+f047
			0xf021, 0xf021, -- ICON_FA_ARROWS_ROTATE 				"\xef\x80\xa1" U+f021
			0xe4ba, 0xe4ba, -- ICON_FA_ARROWS_LEFT_RIGHT_TO_LINE	"\xee\x92\xba" U+e4ba
			0xf0c4, 0xf0c4, -- ICON_FA_CUT					"\xef\x83\x84" U+f0c4
			0xf0c5, 0xf0c5, -- ICON_FA_COPY					"\xef\x83\x85" U+f0c5
			0xf0ea, 0xf0ea, -- ICON_FA_PASTE				"\xef\x83\xaa" U+f0ea
	}}
	ImGuiAnt.FontAtlasBuild(fonts)
end

local memfs = import_package "ant.vfs".memory
function m:init()
	-- memfs.init()
    world.__EDITOR__ = true
    widget_utils.load_imgui_layout(global_data.editor_root / "imgui.layout")
    window.set_title("Editor")
	local __ANT_EDITOR__ = world.args.ecs.__ANT_EDITOR__
	global_data:update_project_root(__ANT_EDITOR__)
    start_fileserver(tostring(sys.exe_path()), __ANT_EDITOR__)
    -- log_widget.init_log_receiver()
    -- console_widget.init_console_sender()
	--filewatch
	if global_data.project_root then
		local bfw = require "bee.filewatch"
		local fw = bfw.create()
		fw:add(global_data.project_root:string())
		global_data.filewatch = fw
	end
	
	init_font()

	icons:init(assetmgr)
	if editor_setting.setting.camera == nil then
        editor_setting.update_camera_setting(0.1)
    end
    world:pub { "camera_controller", "move_speed", editor_setting.setting.camera.speed }
    world:pub { "camera_controller", "stop", true}
    world:pub { "UpdateDefaultLight", true }
end

local function init_camera()
    local mq = w:first "main_queue camera_ref:in"
    local e <close> = world:entity(mq.camera_ref)
    local eye, at = math3d.vector(0, 5, -10), mc.ZERO_PT
    iom.set_position(e, eye)
    iom.set_direction(e, math3d.normalize(math3d.sub(at, eye)))
    local f = icamera.get_frustum(e)
    f.n, f.f = 1, 1000
    icamera.set_frustum(e, f)
end

local light_gizmo = ecs.require "gizmo.light"
function m:init_world()
    irq.set_view_clear_color("main_queue", 0x353535ff)
    init_camera()
    light_gizmo.init()
	world:pub {"ResetPrefab"}
	world:pub {"save_layout", tostring(global_data.editor_root) .. "/imgui.layout" }
end

function m:post_init()
	local font = import_package "ant.font"
    font.import "/pkg/ant.resources.binary/font/Alibaba-PuHuiTi-Regular.ttf"
end

function m:data_changed()

end

function m:exit()
	if global_data.fileserver and global_data.fileserver.subprocess then
		global_data.fileserver.subprocess:wait()
	end
end
