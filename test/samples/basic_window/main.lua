package.path = table.concat({
	"engine/?.lua",
	"engine/?/?.lua",
	"?.lua",
}, ";")

require 'runtime.vfs'
require 'runtime.errlog'
require "filesystem"

local native = require "window.native"
local window = require "window"
local bgfx = require "bgfx"
local plat_module = require "platform"
local math3d = require "math3d"
local ms = math3d.new()

local width, height

local callback = {}

local plat = plat_module.OS:upper()
local platform_relates = {
	WINDOWS={
		shadertype="d3d11",
		renderer="DIRECT3D11",
	},
	IOS={
		shadertype="metal",
		renderer="METAL",
	},
	OSX={
		shadertype="metal",
		renderer="METAL",
	},
	ANDROID={
		shadertype="spirv",
		renderer="VLUKAN",
	}
}
local function default_shader_type()
	local pi = platform_relates[plat]
	return pi.shadertype
end
local function default_renderer()
	local pi = platform_relates[plat]
	return pi.renderer
end
local shaderpath = "shaders/src"

local cube = {}

local function init_hw(nwh, context, w, h)
	width, height = w, h
	bgfx.init {
		nwh = nwh,
		context = context,
		renderer = default_renderer(),
		width = width,
		height = height,
		reset = "v",
	}

	bgfx.set_view_rect(0, 0, 0, width, height)
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)
	bgfx.set_debug "T"

	local shadertypes = {
		NOOP       = "d3d9",
		DIRECT3D9  = "d3d9",
		DIRECT3D11 = "d3d11",
		DIRECT3D12 = "d3d11",
		GNM        = "pssl",
		METAL      = "metal",
		OPENGL     = "glsl",
		OPENGLES   = "essl",
		VULKAN     = "spirv",
	}
	local vfs = require "vfs"
	vfs.identity("."..plat_module.OS:lower() .. "_" .. assert(shadertypes[bgfx.get_caps().rendererType]))
end

local function program_load(vspath, fspath)
	local function createshader(filepath)
		local vfs = require "vfs"
		local rp = vfs.realpath(filepath)
		print("realpath:", filepath, rp)
		local fh = io.open(rp, "rb")
		if fh == nil then
			error(string.format("not found path:", filepath))
		end

		local content = fh:read "a"
		fh:close()

		local h = bgfx.create_shader(content)
		if h == nil then
			error("create vertex shader failed")
		end
		bgfx.set_name(h, filepath)
		return h
	end

	local vh = createshader(vspath)
	local fh = createshader(fspath)

	return bgfx.create_program(vh, fh)
end

local function init_cube()
	cube.prog = program_load(shaderpath .. "/cubes/vs_cubes.sc", shaderpath .. "/cubes/fs_cubes.sc")

	cube.state = bgfx.make_state({ PT = "TRISTRIP" } , nil)	-- from BGFX_STATE_DEFAULT
	cube.vdecl = bgfx.vertex_layout {
		{ "POSITION", 3, "FLOAT" },
		{ "COLOR0", 4, "UINT8", true },
	}

	cube.vb = bgfx.create_vertex_buffer({
			"fffd",
			-1.0,  1.0,  1.0, 0xff000000,
				1.0,  1.0,  1.0, 0xff0000ff,
			-1.0, -1.0,  1.0, 0xff00ff00,
				1.0, -1.0,  1.0, 0xff00ffff,
			-1.0,  1.0, -1.0, 0xffff0000,
				1.0,  1.0, -1.0, 0xffff00ff,
			-1.0, -1.0, -1.0, 0xffffff00,
				1.0, -1.0, -1.0, 0xffffffff,
		},
		cube.vdecl)
	cube.ib = bgfx.create_index_buffer{
		0, 1, 2, 3, 7, 1, 5, 0, 4, 2, 6, 7, 4, 5,
	}
end

local function init_view()
	assert(width); assert(height)
	bgfx.set_view_rect(0, 0, 0,width, height)
	local viewmat = ms({0, 0, -5, 1}, {0, 0, 0, 0}, "lm")
	local projmat = ms({ type = "mat", fov = 60, aspect = width/height } , "m")
	bgfx.set_view_transform(0, viewmat, projmat)
end

function callback.init(nwh, context, w, h)
	init_hw(nwh, context, w, h)
	init_cube()
	init_view()
end

function callback.error(err)
	print(err)
end

function callback.mouse_move(x,y)
	print("mouse_move", x, y)
end

function callback.mouse_wheel(x,y, delta)
	print("mouse_wheel", x, y, delta)
end

function callback.mouse_click(what, press, x, y)
	print("mouse_click", what, press, x, y)
end

function callback.keyboard(key, press, state)
	local ctrl = state & 0x01
	local alt = state & 0x02
	local shift = state & 0x04
	local sys = state & 0x08
	local leftOrright = state & 0x10
	print("KEYBOARD", key, "ctrl", ctrl, "alt", alt, "shift", shift, "sys", sys, "left|right", leftOrright, "is pressed", press)
end


function callback.update()
	bgfx.touch(0)

	bgfx.set_view_clear(0, "CD", 0xffff0000, 1, 0)

	bgfx.set_state(cube.state)

	bgfx.set_vertex_buffer(cube.vb)
	bgfx.set_index_buffer(cube.ib)
	bgfx.set_state(cube.state)
	bgfx.submit(0, cube.prog)

	bgfx.frame()
end

function callback.exit()
	print("Exit")
	bgfx.shutdown()
end

window.register(callback)

local function init()

end

init()

native.create(1024, 768, "Hello")
native.mainloop()
