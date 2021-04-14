local bgfx = require "bgfx"
local datalist = require "datalist"
local fs        = require "filesystem"
local lfs       = require "filesystem.local"

local setting   = import_package "ant.settings".setting
local FX_CACHE = {}
local fxcompile = require "fx.compile"

local function create_param(fx)
    local param = require "fx.stringify"(fx.setting)
    fx.param = param
    return param
end

local function read_default_setting_from_file()
    local f = fs.open (fs.path "/pkg/ant.resources/settings/default.setting")
    local c = f:read "a"
    f:close()
    return c
end

local default_setting       = datalist.parse(read_default_setting_from_file())
default_setting.depth_type  = setting:get 'graphic/shadow/type'
default_setting.bloom       = setting:get 'graphic/postprocess/bloom/enable' and "on" or "off"

local function merge(a, b)
    for k, v in pairs(b) do
        if not a[k] then
            a[k] = v
        end
    end
end

local function read_fx(fx, setting)
    setting = setting or {}
    if fx.setting then
        merge(setting, fx.setting)
    end
    merge(setting, default_setting)
    return {
        vs = fx.vs,
        fs = fx.fs,
        cs = fx.cs,
        setting = setting
    }
end

local function get_hash(fx)
    if fx.cs then
        return fx.cs
    end
    return fx.vs..fx.fs
end

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

local function create_compute_program(cs)
    local prog = bgfx.create_program(cs, false)
    if prog then
        local uniforms = {}
        local mark = {}
        uniform_info(cs, uniforms, mark)
        return prog, uniforms
    else
        error(string.format("create program failed, cs:%d", cs))
    end
end

local function readfile(filename)
	local f = assert(lfs.open(filename, "rb"))
	local data = f:read "a"
	f:close()
	return data
end

local function load_shader(fx, stage)
    local input = fx[stage]
    if input == nil then
        error(("invalid stage:%s in fx file"):format(stage))
    end
    local h = bgfx.create_shader(readfile(fxcompile.get_shader(fx, stage)))
    bgfx.set_name(h, input)
    return h
end

local function create_program(fx)
    if fx.cs then
        return create_compute_program(
            load_shader(fx, "cs")
        )
    else
        return create_render_program(
            load_shader(fx, "vs"),
            load_shader(fx, "fs")
        )
    end
end

local function get_fx_cache(fx)
    local key = create_param(fx)
    if not FX_CACHE[key] then
        FX_CACHE[key] = {}
    end
    return FX_CACHE[key]
end

local function loader(input, setting)
    local fx = read_fx(input, setting)
    local cache = get_fx_cache(fx)
    local schash = get_hash(fx)
    local res = cache[schash]
    if res then
        return res
    end
    fx.prog, fx.uniforms = create_program(fx)
    cache[schash] = fx
    return fx
end

local function compile(input, setting)
    local fx = read_fx(input, setting)
    create_param(fx)
    if fx.vs then fxcompile.get_shader(fx, "vs") end
    if fx.fs then fxcompile.get_shader(fx, "fs") end
    if fx.cs then fxcompile.get_shader(fx, "cs") end
end

local function unloader(res)
    bgfx.destroy(assert(res.prog))
end

return {
    set_identity = fxcompile.set_identity,
    compile = compile,
    loader = loader,
    unloader = unloader,
}
