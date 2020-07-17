local lfs = require "filesystem.local"
local fs = require "filesystem"
local sha1 = require "hash".sha1
local datalist = require "datalist"
local toolset = require "fx.toolset"
local IDENTITY
local PLATFORM
local RENDERER
local BINPATH
local SHARER_INC = lfs.current_path() / "packages/resources/shaders"

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

local function init(identity)
    IDENTITY = identity
    PLATFORM, RENDERER = IDENTITY:match "(%w+)_(%w+)"
    BINPATH = fs.path ".build/sc":localpath() / identity
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
    local ok, err, deps = toolset.compile {
        platform = PLATFORM,
        renderer = RENDERER,
        input = input,
        output = output,
        includes = {SHARER_INC},
        stage = stage,
        macros = get_macros(setting),
    }
    if not ok then
        error("compile failed: " .. input .. "\n\n" .. err)
    end
    return deps
end

local function get_shader(path, stage, fx)
    local hashpath = get_filename(path)
    local output = BINPATH / hashpath / stage
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
    init = init,
    get_shader = get_shader,
}
