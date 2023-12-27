local ecs       = ...
local world     = ecs.world
local bgfx      = require "bgfx"
local math3d    = require "math3d"
local layoutmgr = require "layoutmgr"
local fs        = require "filesystem"
local sampler   = require "sampler"
local platform  = require "bee.platform"
local iviewport = ecs.require "ant.render|viewport.state"
local OS        = platform.os

local caps = bgfx.get_caps()

local renderer<const> = caps.rendererType

local is = ecs.system "init_system"

local mesh = {
    ib = {
        handle = bgfx.create_index_buffer(
            bgfx.memory_buffer("w", {0, 1, 2, 2, 3, 0})
            ),
        start = 0,
        num = 6,
    },
    vb = {
        handle = bgfx.create_vertex_buffer(
            bgfx.memory_buffer("fff", {
                -1,-1, 0,
                -1, 1, 0,
                 1, 1, 0,
                 1,-1, 0,
            }), layoutmgr.get "p3".handle, ""
        ),
        start = 0,
        num = 4,
    }
}

local function create_uniform(h, mark)
    local name, type, num = bgfx.get_uniform_info(h)
    if mark[name] then
        return
    end
    mark[name] = true
    return { handle = h, name = name, type = type, num = num }
end

local function uniform_info(shader, uniforms, mark)
    local shaderuniforms = bgfx.get_shader_uniforms(shader)
    if shaderuniforms then
        for _, h in ipairs(shaderuniforms) do
            uniforms[#uniforms+1] = create_uniform(h, mark)
        end
    end
end

local function create_render_program(vs, fs)
    local prog = bgfx.create_program(vs, fs, false)
    if prog then
        local uniforms = {}
        local mark = {}
        uniform_info(vs, uniforms, mark)
        if fs then
            uniform_info(fs, uniforms, mark)
        end
        return prog, uniforms
    else
        error(string.format("create program failed, vs:%d, fs:%d", vs, fs))
    end
end

local function read_file(filename)
    local f<close> = io.open(filename:localpath():string(), "rb")
    return f:read "a"
end

local function load_shader(shaderfile)
    local h = bgfx.create_shader(read_file(shaderfile))
    bgfx.set_name(h, shaderfile:string())
    return h
end


local material = {
    depth = {
        shader = {},
        state = bgfx.make_state {
            ALPHA_REF = 0,
            CULL = "CCW",
            DEPTH_TEST = "LESS",
            MSAA = true,
            WRITE_MASK = "Z",
        }
    },
    mesh = {
        shader = {},
        state = bgfx.make_state {
            ALPHA_REF = 0,
            CULL = "CCW",
            DEPTH_TEST = "EQUAL",
            MSAA = true,
            WRITE_MASK = "RGBA",
        },
        simple_state = bgfx.make_state {
            ALPHA_REF = 0,
            CULL = "CCW",
            DEPTH_TEST = "LEQUAL",
            MSAA = true,
            WRITE_MASK = "RGBAZ",
        },
    },
    fullscreen = {
        shader = {},
        state = bgfx.make_state {
            ALPHA_REF = 0,
            CULL = "CW",
            DEPTH_TEST = "ALWAYS",
            MSAA = true,
            PT = "TRISTRIP",
            WRITE_MASK = "RGBA"
        }
    }
}

local function load_program(shader, vsfile, fsfile)
    local vshandle = load_shader(vsfile)
    local fshandle
    if fsfile then
        fshandle = load_shader(fsfile)
    end
    shader.prog, shader.uniforms = create_render_program(vshandle, fshandle)
end

local function shader_path(name)
    return fs.path(("/pkg/ant.test.native_bgfx/shaders/bin/%s/%s/%s"):format(OS, renderer:lower(), name))
end

load_program(material.mesh.shader,          shader_path "vs_mesh.bin", shader_path "fs_mesh.bin")
load_program(material.fullscreen.shader,    shader_path "vs_quad.bin", shader_path "fs_quad.bin")

load_program(material.depth.shader,         shader_path "vs_mesh.bin")

local function create_tex2d(filename, flags)
    local f = read_file(filename)
    local h = bgfx.create_texture(f, flags)
    bgfx.set_name(h, filename:string())
    return h
end

local texhandle = create_tex2d(fs.path "/pkg/ant.test.native_bgfx/textures/2x2.dds", sampler{
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
    COLOR_SPACE="sRGB",
})


local viewid = 2

function is:init()
    
end

local fb_size = {w=iviewport.viewrect.w, h=iviewport.viewrectt.h}

local function create_fb1(rbs, viewid)
    local fbhandle = bgfx.create_frame_buffer(rbs, true)
    bgfx.set_view_frame_buffer(viewid, fbhandle)
    return viewid, {handle = fbhandle, rb_handles=rbs}
end

local function create_fb(rbs, viewid)
    local handles = {}
    for _, rb in ipairs(rbs) do
        handles[#handles+1] = bgfx.create_texture2d(rb.w, rb.h, false, rb.layers, rb.format, rb.flags)
    end

    return create_fb1(handles, viewid)
end
local sampleflag = sampler{
    RT = "RT_ON",
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
}

local depth_viewid, depth_fb = create_fb({
    {
        w = fb_size.w,
        h = fb_size.h,
        format = "D24S8",
        layers = 1,
        flags = sampleflag,
    },
}, 0)

local fb_viewid, fb = create_fb1({
    bgfx.create_texture2d(
        fb_size.w,
        fb_size.h,
        false,
        1,
        "RGBA16F",
        sampleflag), depth_fb.rb_handles[1]}, 1)

local function test_fb(viewmat, projmat)
    bgfx.touch(depth_viewid)
    bgfx.set_view_clear(depth_viewid, "D", 0, 1.0, 0.0)
    bgfx.set_view_transform(depth_viewid, viewmat, projmat)
    bgfx.set_view_rect(depth_viewid, 0, 0, fb_size.w, fb_size.h)
    bgfx.set_state(material.depth.state)
    bgfx.set_vertex_buffer(0, mesh.vb.handle, mesh.vb.start, mesh.vb.num)
    bgfx.set_index_buffer(mesh.ib.handle, mesh.ib.start, mesh.ib.num)
    bgfx.submit(depth_viewid, material.depth.shader.prog, 0)

    bgfx.touch(fb_viewid)
    bgfx.set_view_clear(fb_viewid, "C", 0x000000ff, 1.0, 0.0)
    bgfx.set_view_transform(fb_viewid, viewmat, projmat)
    bgfx.set_view_rect(fb_viewid, 0, 0, fb_size.w, fb_size.h)
    bgfx.set_state(material.mesh.state)
    bgfx.set_vertex_buffer(0, mesh.vb.handle, mesh.vb.start, mesh.vb.num)
    bgfx.set_index_buffer(mesh.ib.handle, mesh.ib.start, mesh.ib.num)
    
    bgfx.submit(fb_viewid, material.mesh.shader.prog, 0)

    bgfx.touch(viewid)
    bgfx.set_view_rect(viewid, 0, 0, fb_size.w, fb_size.h)
    bgfx.set_state(material.fullscreen.state)
    bgfx.set_vertex_buffer(0, mesh.vb.handle, 0, 3)
    bgfx.set_texture(0, material.fullscreen.shader.uniforms[1].handle, fb.rb_handles[1])
    bgfx.submit(viewid, material.fullscreen.shader.prog, 0)
end

local function find_uniform(shader, name)
    for _, u in ipairs(shader.uniforms) do
        if u.name == name then
            return u.handle
        end
    end
end

local function draw_simple_mode(viewmat, projmat)
    --bgfx.touch(viewid)
    bgfx.set_view_clear(viewid, "CD", 0x808080ff, 1.0, 0.0)
    bgfx.set_view_transform(viewid, viewmat, projmat)
    bgfx.set_view_rect(viewid, 0, 0, fb_size.w, fb_size.h)

    bgfx.set_state(material.mesh.simple_state)
    bgfx.set_vertex_buffer(0, mesh.vb.handle, mesh.vb.start, mesh.vb.num)
    bgfx.set_index_buffer(mesh.ib.handle, mesh.ib.start, mesh.ib.num)
    
    bgfx.submit(viewid, material.mesh.shader.prog, 0)
end

function is:update()
    bgfx.touch(viewid)

    local viewmat = math3d.value_ptr(math3d.lookat(math3d.vector(0, 0, -10), math3d.vector(0, 0, 0), math3d.vector(0, 1, 0)))
    local projmat = math3d.value_ptr(math3d.projmat{aspect=fb_size.w/fb_size.h, fov=90, n=0.01, f=100})

    local colorhandle = find_uniform(material.mesh.shader, "u_color")
    if colorhandle then
        bgfx.set_uniform(colorhandle, math3d.value_ptr(math3d.vector(0.5, 0.5, 0.5, 1.0)))
    end

    local tex = find_uniform(material.mesh.shader, "s_tex")
    if tex then
        bgfx.set_texture(0, tex, texhandle)
    end
    draw_simple_mode(viewmat, projmat)


end