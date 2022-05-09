local s = {}

local rmat = require "render.material"

local cr = import_package "ant.compile_resource"

local math3d = require "math3d"
local bgfx = require "bgfx"

local COBJ = rmat.cobject{
	bgfx = assert(bgfx.CINTERFACE) ,
    math3d = assert(math3d.CINTERFACE),
    encoder = assert(bgfx.encoder_get()),
}

local system_attribs = rmat.system_attribs(COBJ, {

})

local function load_fx(fx, setting)
	setting = setting or {}
	local newfx = { setting = setting }
	local function check_resolve_path(p)
		newfx[p] = fx[p]
	end
	check_resolve_path "varying_path"
	check_resolve_path "vs"
	check_resolve_path "fs"
	check_resolve_path "cs"
	return cr.load_fx(newfx)
end

local testobj = {}

local function create_texture()
    return bgfx.create_texture2d(2, 2, false, 1, "RGBA32F", "", bgfx.memory_buffer("ffff", {
        1.0, 0.0, 0.0, 1.0,
        0.0, 1.0, 0.0, 1.0,
        0.0, 0.0, 1.0, 1.0,
        1.0, 1.0, 1.0, 1.0
    }))
end

function s.init()
    local fx = load_fx {
        vs = "/pkg/ant.resources/shaders/simple/quad/vs_simplequad.sc",
        fs = "/pkg/ant.resources/shaders/simple/quad/fs_simplequad.sc"
    }

    local function find_uniform(name)
        for _, u in ipairs(fx.uniforms) do
            if u.name == name then
                return u
            end
        end
    end

    local properties = {
        u_color = {type="u", handle = find_uniform "u_color".handle, value = math3d.vector(1, 0, 0, 0)},
        s_tex = {stage=0, handle = assert(find_uniform "s_tex").handle, value = create_texture(), type = 't'}
    }
    local state = bgfx.make_state {
        ALPHA_REF = 0,
        CULL = "NONE",
        DEPTH_TEST = "ALWAYS",
        PT = "TRISTRIP",
        WRITE_MASK = "RGBA",
    }
    local material = rmat.material(COBJ, state, properties)
    local mi = material:instance()

    bgfx.encoder_begin()
    mi{}
    bgfx.encoder_end()
end

function s.render()

end

return s