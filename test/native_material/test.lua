local s = {}

local cr = import_package "ant.compile_resource"

local fs        = require "filesystem"
local math3d    = require "math3d"
local bgfx      = require "bgfx"
local RM        = require "material"    --ant.material/material
local RA        = require "arena"       --ant.material/arena

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

local function material_init()
    --TODO: need copy code from ext_material if we do not want to depend ant.asset
    local mfn = "/pkg/ant.native_material/simplequad.material"
    local mf = cr.compile_file(fs.path(mfn .. "|source.ant"))
    local c; do
        local f<close> = assert(io.open(mf:string(), "r"))
        c = f:read "a"
    end

    bgfx.create_program()
    local fx
    
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
        local imaterial = ecs.require "ant.asset|material"
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
    local material = RA.material_load("TEST", state, fx.prog, {}, properties)
    local mi = RM.create_instance(material)

    local state2 = bgfx.make_state{
        ALPHA_REF = 0,
        CULL = "NONE",
        DEPTH_TEST = "LESS",
        PT = "TRISTRIP",
        WRITE_MASK = "RGBAZ",
    }
    local material2 = RA.material_load("TEST2", state2, properties, fx.prog, {}, properties)
    local mi2 = RM.create_instance(material2)

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

function s.init()
    --material_init()
end

function s.render()
    bgfx.touch(0)
end

return s