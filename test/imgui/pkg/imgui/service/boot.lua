local imgui = require "imgui"
local bgfx = require "bgfx"
local vfs = require "vfs"
local fastio = require "fastio"
local datalist = require "datalist"
local platform = require "bee.platform"

local event = {}

function event.size()
end

function event.dropfiles()
end

local viewid = -1
function event.viewid()
    viewid = viewid + 1
    return viewid
end

local WIDTH <const> = 1280
local HEIGHT <const> = 720

imgui.v2.CreateContext(event)
local nwh = imgui.v2.CreateMainWindow(WIDTH, HEIGHT)
imgui.v2.Init(nwh)

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
imgui.InitRender(
    imgui_font.prog,
    imgui_image.prog,
    imgui_font.uniforms.s_tex,
    imgui_image.uniforms.s_tex
)

local Font = imgui.font.SystemFont
local function glyphRanges(t)
    assert(#t % 2 == 0)
    local s = {}
    for i = 1, #t do
        s[#s+1] = ("<I4"):pack(t[i])
    end
    s[#s+1] = "\x00\x00\x00"
    return table.concat(s)
end
if platform.os == "windows" then
    imgui.font.Create {
        { Font "Segoe UI Emoji" , 18, glyphRanges { 0x23E0, 0x329F, 0x1F000, 0x1FA9F }},
        { Font "黑体" , 18, glyphRanges { 0x0020, 0xFFFF }},
    }
elseif platform.os == "macos" then
    imgui.font.Create { { Font "华文细黑" , 18, glyphRanges { 0x0020, 0xFFFF }} }
elseif platform.os == "ios" then
    imgui.font.Create { { Font "Heiti SC" , 18, glyphRanges { 0x0020, 0xFFFF }} }
else
    error("unknown os:" .. platform.os)
end

local loop = require "loop"
while imgui.v2.DispatchMessage() do
    imgui.v2.NewFrame()
    loop.update(0)
    imgui.Render()
    bgfx.frame()
end
