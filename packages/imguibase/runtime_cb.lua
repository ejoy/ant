local window = require "window"

local assetutil = import_package "ant.asset".util
local renderpkg = import_package "ant.render"
local fs = require "filesystem"
local thread = require "thread"
local imgui = require "imgui.ant"
local platform = require "platform"
local inputmgr = require "inputmgr"

local viewidmgr = renderpkg.viewidmgr
local rhwi = renderpkg.hwi
local font = imgui.font
local Font = platform.font
local imguiIO = imgui.IO
local debug_traceback = debug.traceback
local thread_sleep = thread.sleep

local LOGERROR = __ANT_RUNTIME__ and log.error or print
local debug_update = __ANT_RUNTIME__ and require 'runtime.debug'


local callback = {}

local packages, systems
local world
local world_update

local logic_cb

local ui_viewid = viewidmgr.generate "ui"

local function imgui_resize(width, height)
    local xdpi, ydpi = rhwi.dpi()
    local xscale = math.floor(xdpi/96.0+0.5)
    local yscale = math.floor(ydpi/96.0+0.5)
    imgui.resize(width/xscale, height/yscale, xscale, yscale)
end

function callback.init(nwh, context, width, height)
    imgui.CreateContext(nwh)
    rhwi.init {
        nwh = nwh,
        context = context,
        width = width,
        height = height,
    }
    imgui.ant.viewid(ui_viewid);
    local imgui_font = assetutil.create_shader_program_from_file(fs.path "/pkg/ant.imguibase/shader/font.fx").shader
    imgui.ant.font_program(
        imgui_font.prog,
        imgui_font.uniforms.s_tex.handle
    )
    local imgui_image = assetutil.create_shader_program_from_file(fs.path "/pkg/ant.imguibase/shader/image.fx").shader
    imgui.ant.image_program(
        imgui_image.prog,
        imgui_image.uniforms.s_tex.handle
    )
    imgui_resize(width, height)
    inputmgr.init_keymap(imgui)
    window.set_ime(imgui.ime_handle())
    if platform.OS == "Windows" then
        font.Create { { Font "黑体" ,     18, "ChineseFull"} }
    elseif platform.OS == "macOS" then
        font.Create { { Font "华文细黑" , 18, "ChineseFull"} }
    else -- iOS
        font.Create { { Font "Heiti SC" , 18, "ChineseFull"} }
    end
    logic_cb.init(nwh, context, width, height)
end

function callback.mouse_wheel(x, y, delta)
    imgui.mouse_wheel(x, y, delta)
    if not imguiIO.WantCaptureMouse then
        logic_cb.mouse_wheel(x, y, delta)
    end
end

function callback.mouse(x, y, what, state)
    imgui.mouse(x, y, what, state)
    if not imguiIO.WantCaptureMouse then
        logic_cb.mouse(x, y, what, state)
    end
end

local touchid

function callback.touch(x, y, id, state)
    if state == 1 then
        if not touchid then
            touchid = id
            imgui.mouse(x, y, 1, state)
        end
    elseif state == 2 then
        if touchid == id then
            imgui.mouse(x, y, 1, state)
        end
    elseif state == 3 then
        if touchid == id then
            imgui.mouse(x, y, 1, state)
            touchid = nil
        end
    end
    if not imguiIO.WantCaptureMouse then
        logic_cb.touch(x, y, id, state)
    end
end

function callback.keyboard(key, press, state)
    imgui.keyboard(key, press, state)
    if not imguiIO.WantCaptureKeyboard then
        logic_cb.keyboard(key, press, state)
    end 
end

callback.char = imgui.input_char

function callback.size(width,height,_)
    imgui_resize(width,height)
    logic_cb.size(width,height,_)
    rhwi.reset(nil, width, height)
end

function callback.exit()
    imgui.DestroyContext()
    rhwi.shutdown()
    print "exit"
end

function callback.update()
    if debug_update then debug_update() end
    -- rhwi.frame()
    if logic_cb.update() then
        rhwi.frame()
    end
end

local function dispatch(ok, CMD, ...)
    if not ok then
        local ok, err = xpcall(callback.update, debug_traceback)
        if not ok then
            LOGERROR(err)
        end
        thread_sleep(0)
        return true
    end
    local f = callback[CMD]
    if f then
        local ok, err = xpcall(f, debug_traceback, ...)
        if not ok then
            LOGERROR(err)
        end
    end
    return CMD ~= 'exit'
end

local function run()
    local window = require "common.window"
    while dispatch(window.recvmsg()) do
    end
end

local function start(cb)
    logic_cb = cb
    local window = require "common.window"
    window.create(run, 1024, 768)
end

return {
    start = start,
    callback = callback,
}
