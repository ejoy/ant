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

local nwh = imgui.Create(event, WIDTH, HEIGHT)

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
    local material = datalist.parse(readall(path .. "|main.cfg"))
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
imgui.SetFontProgram(
    imgui_font.prog,
    imgui_font.uniforms.s_tex
)
local imgui_image = load_material "/pkg/ant.imgui/materials/image.material"
imgui.SetImageProgram(
    imgui_image.prog,
    imgui_image.uniforms.s_tex
)

local loop = require "loop"
loop.init()
while imgui.NewFrame() do
    loop.update(0)
    imgui.Render()
    bgfx.frame()
end
