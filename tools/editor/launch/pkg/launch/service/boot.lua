local imgui = require "imgui"
local bgfx = require "bgfx"
local vfs = require "vfs"
local fastio = require "fastio"
local datalist = require "datalist"
local platform = require "bee.platform"
local window = require "window"
local inputmgr = import_package "ant.inputmgr"

local WindowMessage = {}

local WIDTH <const> = 720
local HEIGHT <const> = 450

imgui.CreateContext()
imgui.io.ConfigFlags = imgui.flags.Config {
    "NavEnableKeyboard",
    "DockingEnable",
    "NavNoCaptureKeyboard",
    "DpiEnableScaleViewports",
    "DpiEnableScaleFonts",
}
local nwh = window.init(WindowMessage, ("%dx%d"):format(WIDTH, HEIGHT))
imgui.SetWindowTitle("EditorLauncher")
imgui.SetWindowPos(1280, 720)
bgfx.init {
    nwh      = nwh,
    width    = WIDTH,
    height   = HEIGHT,
    renderer = "DIRECT3D11",
    loglevel = 3,
    reset    = "s",
}

local caps = bgfx.get_caps()
local renderer = caps.rendererType:lower()
vfs.call("RESOURCE_SETTING", ("%s-%s"):format(platform.os, renderer))

local function readall(path)
    local memory = vfs.read(path) or error(("`read `%s` failed."):format(path))
    return fastio.wrap(memory)
end

local function load_material(path)
    local material = datalist.parse(readall(path .. "|source.ant"))
    local vsh = bgfx.create_shader(bgfx.memory_buffer(readall(path .. "|vs.bin")))
    local fsh = bgfx.create_shader(bgfx.memory_buffer(readall(path .. "|fs.bin")))
    bgfx.set_name(vsh, material.fx.vs)
    bgfx.set_name(fsh, material.fx.fs)
    local prog = bgfx.create_program(vsh, fsh, false)
    local uniforms = {}
    for _, h in ipairs(bgfx.get_shader_uniforms(vsh) or {}) do
        local name = bgfx.get_uniform_info(h)
        uniforms[name] = h
    end
    for _, h in ipairs(bgfx.get_shader_uniforms(fsh) or {}) do
        local name = bgfx.get_uniform_info(h)
        uniforms[name] = h
    end
    return {
        prog = prog,
        uniforms = uniforms,
    }
end

local imgui_font = load_material "/pkg/ant.imgui/materials/font.material"
local imgui_image = load_material "/pkg/ant.imgui/materials/image.material"
imgui.InitPlatform(nwh)
imgui.InitRender {
    fontProg = imgui_font.fx.prog,
    imageProg = imgui_image.fx.prog,
    fontUniform = imgui_font.fx.uniforms.s_tex.handle,
    imageUniform = imgui_image.fx.uniforms.s_tex.handle,
    viewIdPool = { 0 },
}

local launch = require "launch_panel"
launch.init()
inputmgr:enable_imgui()
while window.peekmessage() do
    inputmgr:filter_imgui(WindowMessage, {})
    imgui.NewFrame()
    launch.update(0)
    imgui.Render()
    bgfx.frame()
end
