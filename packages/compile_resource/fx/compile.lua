local lfs = require "filesystem.local"
local fs = require "filesystem"
local sha1 = require "hash".sha1
local datalist = require "datalist"
local toolset = require "fx.toolset"
local IDENTITY
local BINPATH = fs.path "":localpath() / ".build" / "sc"
local SHARER_INC = lfs.current_path() / "packages/resources/shaders"

local setting = import_package "ant.settings"

local function get_filename(pathname)
    pathname = lfs.absolute(fs.path(pathname):localpath()):string():lower():lower()
    local filename = pathname:match "[/]?([^/]*)$"
    return filename.."_"..sha1(pathname)
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

local function set_identity(identity)
    IDENTITY = identity
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
	if setting.depth_type == "linear" then
		macros[#macros+1] = "DEPTH_LINEAR"
    end
    if setting.depth_value == "pack_depth" then
        macros[#macros+1] = "PACK_RGBA8"
    end
	if setting.bloom_enable then
		macros[#macros+1] = "BLOOM_ENABLE"
    end
    if setting.fix_line_width then
        macros[#macros+1] = "FIX_WIDTH"
    end
	macros[#macros+1] = "ENABLE_SRGB_TEXTURE"
	macros[#macros+1] = "ENABLE_SRGB_FB"
	return macros
end

local function compile_debug_shader(platform, renderer)
    if platform == "windows" and renderer:match "direct3d" then
        return true
    end
end

local function do_compile(input, output, stage, setting)
    local platform, renderer = IDENTITY:match "(%w+)_(%w+)"
    input = fs.path(input):localpath():string()
    local ok, err, deps = toolset.compile {
        platform = platform,
        renderer = renderer,
        input = input,
        output = output,
        includes = {SHARER_INC},
        stage = stage,
        macros = get_macros(setting),
        debug = compile_debug_shader(platform, renderer),
    }
    if not ok then
        error("compile failed: " .. input .. "\n\n" .. err)
    end
    return deps
end

local function get_shader(fx, stage)
    local path = fx[stage]
    local hashpath = get_filename(path)
    local output = BINPATH / IDENTITY / hashpath / stage
    local outfile = output / fx.hash
    local depfile = output / ".dep" / fx.hash
    if not do_build(depfile) then
        lfs.create_directories(output / ".dep")
        local deps = do_compile(path, outfile, stage, fx.setting)
        create_depfile(depfile, deps)
    end
    return outfile
end

return {
    set_identity = set_identity,
    get_shader = get_shader,
}
