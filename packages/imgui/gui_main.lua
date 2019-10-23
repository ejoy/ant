local window    = require "window"
local imgui     = require "imgui_wrap"
local bgfx      = require "bgfx"
local platform  = require "platform"
local fs        = require "filesystem"
local renderpkg = import_package "ant.render"
local rhwi      = renderpkg.hardware_interface
local viewidmgr = renderpkg.viewidmgr

local assetpkg  = import_package "ant.asset"
local assetutil = assetpkg.util
local assetmgr  = assetpkg.mgr
local editor    = import_package "ant.editor"

local task      = editor.task
local gui_mgr   = require "gui_mgr"
local gui_input = require "gui_input"
local font = imgui.font
local Font = platform.font
local gui_main  = {}
local attribs   = {}
local main = nil
local initialized = false

local uieditor_viewid = viewidmgr.generate("uieditor")

local function imgui_resize(width, height)
	local xdpi, ydpi = rhwi.dpi()
	local xscale = math.floor(xdpi/96.0+0.5)
	local yscale = math.floor(ydpi/96.0+0.5)
	imgui.resize(width/xscale, height/yscale, xscale, yscale)
end


function gui_main.init(nwh, context, width, height)
	imgui.create(nwh)
    initialized = true
    rhwi.init {
        nwh = nwh,
        context = context,
        width = width,
        height = height,
	}
    imgui.setDockEnable(true)
    imgui.viewid(viewidmgr.generate("ui"));
    gui_mgr.win_handle = nwh
	local imgui_font = assetutil.create_shader_program_from_file(fs.path "/pkg/ant.imguibase/shader/font.fx").shader
    imgui.font_program(
        imgui_font.prog,
        imgui_font.uniforms.s_tex.handle
    )
	local imgui_image = assetutil.create_shader_program_from_file(fs.path "/pkg/ant.imguibase/shader/image.fx").shader
    imgui.image_program(
        imgui_image.prog,
        imgui_image.uniforms.s_tex.handle
	)
	imgui_resize(width, height)
    gui_input.size(width,height)
	imgui.keymap(window.keymap)
	window.set_ime(imgui.ime_handle())
    bgfx.set_view_rect(uieditor_viewid, 0, 0, width, height)
    bgfx.set_view_clear(uieditor_viewid, "CD", 0x303030ff, 1, 0)

    -- bgfx.set_view_rect(1, 200, 200, width-100, height-100)
    -- bgfx.set_view_clear(1, "CD", 0xffff00ff, 1, 0)
    -- bgfx.set_debug "ST"
    if platform.OS == "Windows" then
        font.Create { { Font "Arial" ,16, "Default"},{ Font "黑体" ,16, "ChineseFull"} }
    elseif platform.OS == "macOS" then
        font.Create { { Font "华文细黑" , 16, "\x20\x00\xFF\xFF\x00"} }
    else -- iOS
        font.Create { { Font "Heiti SC" ,    16, "\x20\x00\xFF\xFF\x00"} }
    end
    if main.init then
        main.init(nwh, context, width, height)
    end
    gui_mgr.after_init()
    print("init completely:",os.clock())
end

function gui_main.size(width,height,type)
    -- log("callback.size",width,height,type)
    imgui.resize(width,height)
    rhwi.reset(nil, width, height)
    bgfx.set_view_rect(uieditor_viewid, 0, 0, width, height)
    gui_input.size(width,height,type)
    if main.size then
        main.size(width,height,type)
    end
end

function gui_main.char(code)
    imgui.input_char(code)
end

function gui_main.error(err)
    log.error(err)
    if main.error then
        main.error(err)
    end
end

function gui_main.mouse(x,y,what,state)
    imgui.mouse(x, y, what, state)
    gui_input.mouse(x, y, what, state)
    -- if state == 2 then
    --     print("guimain, move")
    --     gui_input.mouse_move(x,y)
    -- else
    --     gui_input.mouse_click(x,y,what,state==1)
    -- end
end

function gui_main.mouse_wheel(x,y,delta)
    imgui.mouse_wheel(x,y,delta)
    gui_input.mouse_wheel(x,y,delta)

end

-- function gui_main.mouse_click(x, y, what, pressed)
--     -- log("mouse_click",what,pressed)
--     imgui.mouse_click(x, y, what, pressed)
--     gui_input.mouse_click(x, y, what, pressed)
-- end

function gui_main.keyboard(key, press, state)
    imgui.keyboard(key, press, state)
    -- log.trace("key",key,press,state)
    gui_input.keyboard(key, press > 0, state)
end

local os = require "os"
local thread = require "thread"
local last_update = os.clock()
local FRAME_TIME = 1/60
local next_update = last_update + FRAME_TIME
function gui_main.update()
    if not initialized then
        return
    end
    local now = os.clock()
    local delta = now - last_update
    last_update = now
    _update(delta+0.00000001)
    -- local after_update = os.clock()
    -- local wait = next_update-after_update
    -- if wait >0 then
    --     thread.sleep(wait)
    -- end
    -- next_update = next_update + FRAME_TIME
end
function _update(delta)
    local pm = require "antpm"
    gui_mgr.update(delta)

    task.update()
	
	bgfx.touch(uieditor_viewid)
    rhwi.frame()
    if main.update then
        main.update()
    end
    gui_input.clean()
end

function gui_main.exit()
    log("Exit")
    imgui.destroy()
    rhwi.shutdown()
    if main.exit then
        main.exit()
    end
end

function gui_main.dropfiles(paths)
    local a = paths
    log.info("dropfiles",a)
    for i,v in pairs(a) do

        log(v)
    end
    gui_input.set_dropfiles(paths)
end

local function dispatch(ok, CMD, ...)
    if not ok then
        gui_main.update()
		-- local ok, err = xpcall(gui_main.update, debug.traceback)
		-- if not ok then
		-- 	gui_main.error(err)
		-- end
		thread.sleep(0)
		return true
	end
	local f = gui_main[CMD]
    if f then
        f(...)
		-- local ok, err = xpcall(f, debug.traceback, ...)
		-- if not ok then
		-- 	gui_main.error(err)
		-- end
	end
	return CMD ~= 'exit'
end

local function run()
	local window = require "common.window"
	while dispatch(window.recvmsg()) do
	end
end

local function create(m,args)
    main = m

	local window = require "common.window"
	window.create(run, args.screen_width or 1024,  args.screen_height or 728, args.name or "Ant")
end

return {run = create}


