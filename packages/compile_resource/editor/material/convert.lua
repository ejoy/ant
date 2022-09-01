local lfs = require "filesystem.local"
local fs = require "filesystem"
local datalist = require "datalist"
local toolset = require "editor.material.toolset"
local fxsetting = require "editor.material.setting"
local SHARER_INC = lfs.absolute(fs.path "/pkg/ant.resources/shaders":localpath())
local setting = import_package "ant.settings".setting
local serialize = import_package "ant.serialize"
local depends   = require "editor.depends"

local function DEF_FUNC() end

local SETTING_MAPPING = {
    lighting = function (v)
        if v == "on" then
            return "ENABLE_LIGHTING=1"
        end
    end,
    shadow_receive = function (v)
        if v == "on" then
            return "ENABLE_SHADOW=1"
        end
    end,
    os = DEF_FUNC,
    renderer = DEF_FUNC,
    stage = DEF_FUNC,
    varying_path= DEF_FUNC,
    subsurface = DEF_FUNC,
    surfacetype = DEF_FUNC,
    shadow_cast = DEF_FUNC,
}

local enable_cs = setting:get 'graphic/lighting/cluster_shading' ~= 0
local enable_bloom = setting:get "graphic/postprocess/bloom/enable"

local curve_world = setting:data().graphic.curve_world
local curve_world_type_macros<const> = {
    view_sphere = 1,
    cylinder = 2,
}

local function default_macros(setting)
    local m = {
        "ENABLE_SRGB_TEXTURE=1",
        "ENABLE_SRGB_FB=1",
        "ENABLE_IBL=1",
    }

    if enable_cs then
        m[#m+1] = "HOMOGENEOUS_DEPTH=" .. (setting.hd and "1" or "0")
        m[#m+1] = "ORIGIN_BOTTOM_LEFT=" .. (setting.obl and "1" or "0")
        m[#m+1] = "CLUSTER_SHADING=1"
    end

    if curve_world.enable then
        m[#m+1] = "ENABLE_CURVE_WORLD=" .. curve_world_type_macros[curve_world.type]
    end

    if enable_bloom then
        m[#m+1] = "BLOOM_ENABLE=1"
    end

    return m
end

local function get_macros(setting, fxsetting)
    local macros = default_macros(setting)
    for k, v in pairs(fxsetting) do
        local f = SETTING_MAPPING[k]
        if f == nil then
            macros[#macros+1] = k .. '=' .. v
        else
            local t = type(f)
            if t == "function" then
                local tt = f(v)
                if tt then
                    macros[#macros+1] = tt
                end
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

local function readfile(filename)
	local f <close> = assert(lfs.open(filename, "r"))
	return f:read "a"
end

local function writefile(filename, data)
	local f<close> = assert(lfs.open(filename, "wb"))
	f:write(serialize.stringify(data))
end

local function readdatalist(filepath)
	return datalist.parse(readfile(filepath), function(args)
		return args[2]
	end)
end

local function mergeCfgSetting(setting, localpath)
    if setting == nil then
        setting = {}
    elseif type(setting) == "string" then
        setting = serialize.parse(setting, readfile(localpath(setting)))
    else
        assert(type(setting) == "table")
    end
    return fxsetting.adddef(setting)
end

return function (input, output, setting, localpath)
    local mat = readdatalist(input)
    local fx = mat.fx
    fx.setting = mergeCfgSetting(fx.setting, localpath)
    local depfiles = {}

    local varying_path = fx.varying_path
    if varying_path then
        varying_path = localpath(varying_path)
    end
    for _, stage in ipairs {"vs","fs","cs"} do
        if fx[stage] then
            local ok, err, deps = toolset.compile {
                platform = setting.os,
                renderer = setting.renderer,
                input = localpath(fx[stage]),
                output = output / (stage..".bin"),
                includes = {SHARER_INC},
                stage = stage,
                varying_path = varying_path,
                macros = get_macros(setting, fx.setting),
                debug = compile_debug_shader(setting.os, setting.renderer),
            }
            if not ok then
                return false, ("compile failed: " .. input:string() .. "\n\n" .. err)
            end
            depends.append(depfiles, deps)
        end
    end
    writefile(output / "main.cfg", mat)
    return true, depfiles
end
