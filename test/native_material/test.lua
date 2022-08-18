local s = {}

local rmat = require "render.material"

local cr = import_package "ant.compile_resource"

local math3d = require "math3d"
local bgfx = require "bgfx"

local function build_ecs_worldobj()
    local ecs_worldobj = {
        assert(bgfx.CINTERFACE) ,
        assert(bgfx.CINTERFACE) ,
        assert(math3d.CINTERFACE),
        assert(bgfx.encoder_get()),
    }
    local function toint(v)
        local ss = tostring(v)
        ss = ss:match "^%a+: (%x+)$" or s:match "^%a+: 0x(%x+)$"
        return tonumber(assert(ss), 16)
    end

    local t = {}
    for i = 1, #ecs_worldobj do
        t[i] = toint(ecs_worldobj[i])
    end
    return ("<"..("T"):rep(#t)):pack(table.unpack(t))
end

local ecs_ref = build_ecs_worldobj()
for k, v in pairs(rmat) do
    debug.setupvalue(v, 1, ecs_ref)
end

local system_attribs = rmat.system_attribs{}

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

local function update_texture(handle)
    local x, y, w, h = 1, 1, 1, 1
    --base 0
    local layer, mip = 0, 0
    local mem = bgfx.memory("ffff", {
        0.8, 0.8, 0.8, 1.0
    })
    bgfx.update_texture2d(handle, layer, mip, x, y, w, h, mem)
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

    local tex = create_texture()
    update_texture(tex)

    --[[
        local imaterial = import_package "ant.asset|imaterial"
        imaterial.set_property(e, "s_tex", tex)
    ]]

    local properties = {
        u_color = {type="u", handle = find_uniform "u_color".handle, value = math3d.vector(1, 0, 0, 0)},
        s_tex = {stage=0, handle = assert(find_uniform "s_tex").handle, value = tex, type = 't'}
    }
    local state = bgfx.make_state {
        ALPHA_REF = 0,
        CULL = "NONE",
        DEPTH_TEST = "ALWAYS",
        PT = "TRISTRIP",
        WRITE_MASK = "RGBA",
    }
    local material = rmat.material(state, properties, fx.prog)
    local mi = material:instance()

    local state2 = bgfx.make_state{
        ALPHA_REF = 0,
        CULL = "NONE",
        DEPTH_TEST = "LESS",
        PT = "TRISTRIP",
        WRITE_MASK = "RGBAZ",
    }
    local material2 = material:copy(state2)
    local mi2 = material2:instance()

    bgfx.encoder_begin()
    mi{}
    bgfx.submit(0, fx.prog, 0)
    mi2{}
    bgfx.submit(0, fx.prog, 0)
    bgfx.encoder_end()

    mi = nil
    mi2 = nil
    material = nil
    material2 = nil

    collectgarbage "collect"
end

function s.render()

end

return s