local lfs = require "filesystem.local"
local fs = require "filesystem"
local vfs = require "vfs"
local sha1 = require "hash".sha1
local datalist = require "datalist"
local bgfx = require "bgfx"
local c = require "compile"
local stringify = require "fx.stringify"
local toolset = require "fx.toolset"
local render = import_package "ant.render"
local CACHE = {}
local IDENTITY
local PLATFORM
local RENDERER
local BINPATH
local SHARER_INC = lfs.current_path() / "packages/resources/shaders"

local function get_filename(pathname)
    pathname = fs.path(pathname)
    local stem = pathname:stem():string():lower()
    local parent = pathname:parent_path():string():lower()
    return stem.."_"..sha1(parent)
end

local function writefile(filename, data)
	local f = assert(lfs.open(filename, "wb"))
	f:write(data)
	f:close()
end

local function readfile(filename)
	local f = assert(lfs.open(filename, "rb"))
	local data = f:read "a"
	f:close()
	return data
end

local function register(identity)
    local root = vfs.repo()._root
    IDENTITY = identity
    PLATFORM, RENDERER = IDENTITY:match "(%w+)_(%w+)"
    BINPATH = root / ".build" / "fx" / identity
end

local function do_build(depfile)
    if not lfs.exists(depfile) then
        return
    end
	for _, dep in ipairs(datalist.parse(readfile(depfile))) do
		local timestamp, filename = dep[1], lfs.path(dep[2])
		if not lfs.exists(filename) or timestamp ~= lfs.last_write_time(filename) then
			return
		end
	end
	return true
end

local function create_depfile(filename, deps)
    local w = {}
    for _, file in ipairs(deps) do
        local path = lfs.path(file)
        w[#w+1] = ("{%d, %q}"):format(lfs.last_write_time(path), lfs.absolute(path):string())
    end
    writefile(filename, table.concat(w, "\n"))
end

local function get_macros(setting)
	local macros = {}
	if setting.lighting == "on" then
		macros[#macros+1] = "ENABLE_LIGHTING"
	end
	if setting.shadow_receive == "on" then
		macros[#macros+1] = "ENABLE_SHADOW"
	end
	if setting.skinning == "GPU" then
		macros[#macros+1] = "GPU_SKINNING"
	end
	if setting.shadow_type == "linear" then
		macros[#macros+1] = "SM_LINEAR"
	end
	if setting.bloom_enable then
		macros[#macros+1] = "BLOOM_ENABLE"
	end
	macros[#macros+1] = "ENABLE_SRGB_TEXTURE"
	macros[#macros+1] = "ENABLE_SRGB_FB"
	return macros
end

local function do_compile(input, output, stage, setting)
    input = fs.path(input):localpath():string()
	local macros = get_macros(setting)
    local ok, err, deps = toolset.compile {
        platform = PLATFORM,
        renderer = RENDERER,
        input = input,
        output = output,
        includes = {SHARER_INC},
        stage = stage,
        macros = macros,
    }
    if not ok then
        error("compile failed: " .. input .. "\n\n" .. err)
    end
	table.sort(deps)
    table.insert(deps, 1, input)
    return deps
end

local function set_uniform_texture(u, property)
    --TODO: 'stage' info has been written in shader compiled file by bgfx, but it does not keep in memory after reload shader binary file
    -- see: bgfx_p.h:createShader function
    bgfx.set_texture(property.stage, u.handle, property.texture.handle)
end

local function set_uniform(u, property)
    bgfx.set_uniform(u.handle, property)
end

local function set_uniform_array(u, property)
    bgfx.set_uniform(u.handle, table.unpack(property))
end

local function create_uniform(h, mark)
    local name, type, num = bgfx.get_uniform_info(h)
    if mark[name] then
        return
    end
    mark[name] = true
    local uniform = { handle = h, name = name, type = type, num = num }
    if type == "s" then
        assert(num == 1)
        uniform.set = set_uniform_texture
    else
        assert(type == "v4" or type == "m4")
        if num == 1 then
            uniform.set = set_uniform
        else
            uniform.set = set_uniform_array
        end
    end
    return uniform
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

local default_setting = {
	lighting = "on",			-- "on"/"off"
	transparency = "opaticy",	-- "opaticy"/"translucent"
	shadow_cast	= "on",			-- "on"/"off"
	shadow_receive = "off",		-- "on"/"off"
	subsurface = "off",			-- "on"/"off"? maybe has other setting
	skinning = "UNKNOWN",
    shadow_type = render.setting:get 'graphic/shadow/type',
    bloom_enable = render.setting:get 'graphic/postprocess/bloom/enable',
}

local function merge_setting(fx, s)
    local t = fx.setting or {}
    if s then
        for k, v in pairs(s) do
            t[k] = v
        end
    end
    for k, v in pairs(default_setting) do
        if not t[k] then
            t[k] = v
        end
    end
    fx.setting = t
end

local function read_fx(filename, setting)
    local path = c.compile_path(filename)
	local fx = datalist.parse(readfile(path))
    merge_setting(fx, setting)
    return fx
end

local function get_setting_cache(setting)
    local setting_string = stringify(setting)
    local hash = sha1(setting_string):sub(1,7)
    local path = BINPATH / hash
    if CACHE[hash] then
        return CACHE[hash], path
    end
    CACHE[hash] = {}
    lfs.create_directories(path)
    lfs.create_directories(path / ".dep")
    writefile(path / ".setting", setting_string)
    return CACHE[hash], path
end

local function get_hash(fx)
    local shader = fx.shader
    if shader.cs then
        return sha1(shader.cs)
    end
    return sha1(shader.vs..shader.fs)
end

local function load_shader(output, fx, stage)
    local input = fx.shader[stage]
    local hashpath = get_filename(input)
    local outfile = output / hashpath
    local depfile = output / ".dep" / hashpath
    if not do_build(depfile) then
        local deps = do_compile(input, outfile, stage, fx.setting)
        create_depfile(depfile, deps)
    end
    local h = bgfx.create_shader(readfile(outfile))
    bgfx.set_name(h, input)
    return h
end

local function load_fx(output, fx)
    local shader = fx.shader
    if shader.cs == nil then
        fx.prog, fx.uniforms = create_render_program(
            load_shader(output, fx, "vs"),
            load_shader(output, fx, "fs")
        )
    else
        fx.prog, fx.uniforms = create_compute_program(
            load_shader(output, fx, "cs")
        )
    end
end

local function loader(filename, setting)
    local fx = read_fx(filename, setting)
    local cache, output = get_setting_cache(fx.setting)
    local hash = get_hash(fx)
    local res = cache[hash]
    if res then
        return res
    end
    load_fx(output, fx)
    cache[hash] = fx
    return fx
end

local function unloader(res)
    bgfx.destroy(assert(res.shader.prog))
end

return {
    register = register,
    loader = loader,
    unloader = unloader,
}
