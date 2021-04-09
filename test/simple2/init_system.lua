local ecs = ...
local world = ecs.world
local bgfx = require "bgfx"
local math3d = require "math3d"
local declmgr = require "declmgr"
local fs = require "filesystem"
local sampler = require "sampler"
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
            }), declmgr.get "p3".handle, ""
        ),
        start = 0,
        num = 4,
    }
}

local function quad_mesh_vertices(rect)
    local origin_bottomleft = false
	local minv, maxv
	if origin_bottomleft then
		minv, maxv = 0, 1
	else
		minv, maxv = 1, 0
	end
	local x, y, w, h
	if rect then
		x, y = rect.x or 0, rect.y or 0
		w, h = rect.w, rect.h
	else
		x, y = -1, -1
		w, h = 2, 2
	end
	return {
		x, 		y, 		0, 	0, minv,	--bottom left
		x,		y + h, 	0, 	0, maxv,	--top left
		x + w, 	y, 		0, 	1, minv,	--bottom right
		x + w, 	y + h, 	0, 	1, maxv,	--top right
	}
end

local quadmesh = {
    vb = {
        handle = bgfx.create_vertex_buffer(
            bgfx.memory_buffer("fffff", quad_mesh_vertices()),
            declmgr.get "p3|t20".handle, ""
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
    for _, h in ipairs(bgfx.get_shader_uniforms(shader)) do
        uniforms[#uniforms+1] = create_uniform(h, mark)
    end
end

local function create_render_program(vs, fs)
    local prog = bgfx.create_program(vs, fs, false)
    if prog then
        local uniforms = {}
        local mark = {}
        uniform_info(vs, uniforms, mark)
        uniform_info(fs, uniforms, mark)
        return prog, uniforms
    else
        error(string.format("create program failed, vs:%d, fs:%d", vs, fs))
    end
end

local function read_file(filename)
    print(filename)
    print(filename:localpath())
    local f = fs.open(filename, "rb")
    local c = f:read "a"
    f:close()
    return c
end

local function load_shader(shaderfile)
    local h = bgfx.create_shader(read_file(shaderfile))
    bgfx.set_name(h, shaderfile:string())
    return h
end


local material = {
    mesh = {
        shader = {},
        state = bgfx.make_state {
            ALPHA_REF = 0,
            CULL = "CCW",
            DEPTH_TEST = "LESS",
            MSAA = true,
            WRITE_MASK = "RGBAZ",
        }
    },
    fullscreen = {
        shader = {},
        state = bgfx.make_state {
            ALPHA_REF = 0,
            CULL = "CCW",
            DEPTH_TEST = "ALWAYS",
            MSAA = true,
            PT = "TRISTRIP",
            WRITE_MASK = "RGBA"
        }
    }
}

local function load_program(shader, vsfile, fsfile)
    shader.prog, shader.uniforms = create_render_program(load_shader(vsfile), load_shader(fsfile))
end

load_program(material.mesh.shader, fs.path "/pkg/ant.test.simple2/shaders/mesh/vs_mesh.bin", fs.path "/pkg/ant.test.simple2/shaders/mesh/fs_mesh.bin")
load_program(material.fullscreen.shader, fs.path "/pkg/ant.test.simple2/shaders/fullquad/vs_quad.bin", fs.path "/pkg/ant.test.simple2/shaders/fullquad/fs_quad.bin")

local viewid = 1

function is:init()
    
end

local fb_size = {w=world.args.width, h=world.args.height}

local function create_fb(rbs, viewid)
    local handles = {}
    for _, rb in ipairs(rbs) do
        handles[#handles+1] = bgfx.create_texture2d(rb.w, rb.h, false, rb.layers, rb.format, rb.flags)
    end

    local fbhandle = bgfx.create_frame_buffer(handles, true)
    bgfx.set_view_frame_buffer(viewid, fbhandle)
    return viewid, {handle = fbhandle, rb_handles=handles}
end
local sampleflag = sampler.sampler_flag{
    RT="RT_MSAA4",
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
}
local fb_viewid, fb = create_fb({
    {
        w = fb_size.w,
        h = fb_size.h,
        format = "RGBA16F",
        layers = 1,
        flags = sampleflag,
    },
    {
        w = fb_size.w,
        h = fb_size.h,
        format = "D24S8",
        layers = 1,
        flags = sampleflag,
    },

}, 0)


function is:update()
    bgfx.touch(fb_viewid)

    local eye = {0, 0, -10}
    local viewmat = math3d.lookat(math3d.vector(eye), math3d.vector(0, 0, 0), math3d.vector(0, 1, 0))
    
    local projmat = math3d.projmat{aspect=fb_size.w/fb_size.h, fov=90, n=0.01, f=100}
    bgfx.set_view_clear(fb_viewid, "CD", 0x000000ff, 1.0, 0.0)
    bgfx.set_view_transform(fb_viewid, math3d.value_ptr(viewmat), math3d.value_ptr(projmat))
    bgfx.set_view_rect(fb_viewid, 0, 0, fb_size.w, fb_size.h)
    bgfx.set_state(material.mesh.state)
    bgfx.set_vertex_buffer(0, mesh.vb.handle, mesh.vb.start, mesh.vb.num)
    bgfx.set_index_buffer(mesh.ib.handle, mesh.ib.start, mesh.ib.num)
    
    bgfx.submit(fb_viewid, material.mesh.shader.prog, 0)

    bgfx.touch(viewid)
    bgfx.set_view_rect(viewid, 0, 0, fb_size.w, fb_size.h)
    bgfx.set_state(material.fullscreen.state)
    bgfx.set_vertex_buffer(0, quadmesh.vb.handle, quadmesh.vb.start, quadmesh.vb.num)
    bgfx.set_texture(0, material.fullscreen.shader.uniforms[1].handle, fb.rb_handles[1])
    bgfx.submit(viewid, material.fullscreen.shader.prog, 0)
end