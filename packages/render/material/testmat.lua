package.cpath = "bin/?.dll;../../project/material/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local util = require "util"
local math3d = require "math3d"
local material = require "material"

local ctx = {
--	renderer = "OPENGL",
	canvas = iup.canvas{
	--	rastersize = "1024x768",
	--	rastersize = "400x300",
	},
}

local dlg = iup.dialog {
	ctx.canvas,
	title = "material",
	size = "HALFxHALF",
}

local function mainloop()
	math3d.reset()
	bgfx.touch(0)

	bgfx.frame()
end

local COBJECT = material.cobject {
	bgfx = assert(bgfx.CINTERFACE) ,
	math3d = assert(math3d.CINTERFACE),
}
local STATE = bgfx.make_state({ PT = "TRISTRIP" } , nil)	-- from BGFX_STATE_DEFAULT

function ctx.init()
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

	local vs = util.shaderLoad "vs_mesh"
	local fs = util.shaderLoad "fs_mesh"

	local prog = material.program(COBJECT, vs, fs)
	local uniform = prog:info()
	for k,v in pairs(uniform) do
		print(k,v)
	end

	do
	local mat = prog:material(STATE, {
		u_time = math3d.vector(1,2,3,4),
--		tex = { stage = 0, handle = 123 }
	})

	print(mat)

	local info = mat:attribs()
	for k,v in pairs(info) do
		print(k,math3d.tostring(v))
	end
	print(prog)

	local ins = mat:instance()
	ins.u_time = math3d.vector(5,6,7,8)
--	ins.tex = 456

	ins {}

	end
	collectgarbage "collect"
	prog:collect()

--	ctx.prog = util.programLoad("vs_cubes", "fs_cubes")

end

function ctx.resize(w,h)
	ctx.width = w
	ctx.height = h
	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height)
	bgfx.reset(ctx.width,ctx.height, "vmx")
	-- calc lookat matrix, return matrix pointer, and remove top

	local eyepos, at = math3d.vector(0,0,-35), math3d.vector(0, 0, 0)
	local viewmat = math3d.lookat(eyepos, at)
	local projmat = math3d.projmat { fov = 60, aspect = w/h , n = 0.1, f = 100 }
	bgfx.set_view_transform(0, viewmat, projmat)
end


util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(mainloop)

-- util.run will call bgfx.shutdown to destroy everything, so don't call these:
--bgfx.destroy(ctx.vb)
--bgfx.destroy(ctx.ib)
--bgfx.destroy(ctx.prog)
