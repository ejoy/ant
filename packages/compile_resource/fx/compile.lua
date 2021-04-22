if __ANT_RUNTIME__ then
    local fs = require "filesystem"
    local sha1 = require "hash".sha1
    local m = {}
    function m.register()
    end
    function m.get_shader(fx, stage)
        if fx[stage] then
            local hash = sha1(fx.param):sub(1,7)
            return (fs.path(fx[stage]) / (stage..hash) / "main.bin"):localpath()
        end
    end
    return m
end

local lfs = require "filesystem.local"
local fs = require "filesystem"
local sha1 = require "hash".sha1
local datalist = require "datalist"
local toolset = require "fx.toolset"
local IDENTITY
local BINPATH = fs.path "":localpath() / ".build" / "sc"
local SHARER_INC = lfs.absolute(fs.path "/pkg/ant.resources/shaders":localpath())

local setting = import_package "ant.settings".setting

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

local function DEF_FUNC() end

local SETTING_MAPPING = {
    lighting = function (v)
        if v == "on" then
            return "ENABLE_LIGHTING"
        end
    end,
    shadow_receive = function (v)
        if v == "on" then
            return "ENABLE_SHADOW"
        end
    end,
    skinning = function (v)
        if v == "GPU" then
            return "GPU_SKINNING"
        end
    end,
    depth_type = function (v)
        if v == "linear" then
            return "DEPTH_LINEAR"
        elseif v == "pack_depth" then
            return "PACK_RGBA8"
        end
    end,
    bloom = function (v)
        if v == "on" then
            return "BLOOM_ENABLE"
        end
    end,
    fix_line_width = "FIX_WIDTH",
    subsurface = DEF_FUNC,
    surfacetype = DEF_FUNC,
    shadow_cast = DEF_FUNC,
}

local enable_cs = setting:data().graphic.lighting.cluster_shading ~= 0

local function default_macros()
    local m = {
        "ENABLE_SRGB_TEXTURE",
        "ENABLE_SRGB_FB",
        "ENABLE_IBL"
    }

    if enable_cs then
        m[#m+1] = "CLUSTER_SHADING"
    end
    return m
end

local function get_macros(setting)
    local macros = default_macros()

    for k, v in pairs(setting) do
        local f = SETTING_MAPPING[k]
        if f == nil then
            macros[#macros+1] = k
        else
            local t = type(f)
            if t == "function" then
                macros[#macros+1] = f(v)
            elseif t == "string" then
                macros[#macros+1] = f
            else
                error("invalid type")
            end
        end
    end
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
    local hash = sha1(fx.param):sub(1,7)
    local output = BINPATH / IDENTITY / hashpath / (stage .. hash)
    local outfile = output / "main.bin"
    local depfile = output / ".dep"
    if not do_build(depfile) then
        lfs.create_directories(output)
        local deps = do_compile(path, outfile, stage, fx.setting)
        create_depfile(depfile, deps)
    end
    return outfile
end

return {
    set_identity = set_identity,
    get_shader = get_shader,
}
