local lfs = require "filesystem.local"
local fs = require "filesystem"
local datalist = require "datalist"
local toolset = require "editor.material.toolset"
local fxsetting = require "editor.material.setting"
local settingpkg = import_package "ant.settings"
local setting, def_setting = settingpkg.setting, settingpkg.default
local serialize = import_package "ant.serialize"
local depends   = require "editor.depends"

local ENABLE_SHADOW<const> = setting:data().graphic.shadow.enable

local function DEF_FUNC() end

local SHADER_BASE<const>            = lfs.absolute(fs.path "/pkg/ant.resources/shaders":localpath())
local function shader_includes()
    return {
        SHADER_BASE,
    }
end

local SETTING_MAPPING = {
    lighting = function (v)
        if v == "off" then
            return "MATERIAL_UNLIT=1"
        end
    end,
    shadow_receive = function (v)
        if ENABLE_SHADOW and v == "on" then
            return "ENABLE_SHADOW=1"
        end
    end,
    os          = DEF_FUNC,
    renderer    = DEF_FUNC,
    stage       = DEF_FUNC,
    varying_path= DEF_FUNC,
    subsurface  = DEF_FUNC,
    shadow_cast = DEF_FUNC,
}

local enable_cs<const>      = setting:get 'graphic/lighting/cluster_shading' ~= 0
local enable_bloom<const>   = setting:get "graphic/postprocess/bloom/enable"
local fxaa_setting<const>    = setting:data().graphic.postprocess.fxaa
local ao_setting<const>     = setting:data().graphic.ao or def_setting.graphic.ao

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
        "ENABLE_TEXTURE_GATHER=1",
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

    if ao_setting.enable then
        m[#m+1] = "ENABLE_SSAO=1"
        if ao_setting.bent_normal then
            m[#m+1] = "ENABLE_BENT_NORMAL=1"
        end

        if ao_setting.qulity == "high" then
            m[#m+1] = "HIGH_QULITY_SPECULAR_AO=1"
            m[#m+1] = "HIGH_QULITY_NORMAL_RECONSTRUCT=1"
        end
    end

    if fxaa_setting.enable and not fxaa_setting.use_green_as_luma then
        m[#m+1] = "COMPUTE_LUMINANCE_TO_ALPHA=1"
    end

    return m
end

local function is_pbr_material(fx)
    if fx.vs and fx.fs then
        return fx.vs:match "/pkg/ant.resources/shaders/pbr/vs_pbr.sc" and
            fx.fs:match "/pkg/ant.resources/shaders/pbr/fs_pbr.sc"
    end
end

local PBR_TEXTURE_MACROS<const> = {
    s_basecolor = "HAS_BASECOLOR_TEXTURE=1",
    s_normal    = "HAS_NORMAL_TEXTURE=1",
    s_metallic_roughness="HAS_METALLIC_ROUGHNESS_TEXTURE=1",
    s_emissive="HAS_EMISSIVE_TEXTURE=1",
    s_occlusion="HAS_OCCLUSION_TEXTURE=1",
}

local function get_macros(setting, mat)
    local macros = default_macros(setting)
    for k, v in pairs(mat.fx.setting) do
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

    if is_pbr_material(mat.fx) then
        local properties = mat.properties
        for texname, m in pairs(PBR_TEXTURE_MACROS) do
            if properties[texname] then
                macros[#macros+1] = m
            end
        end
    end
	return macros
end

local function compile_debug_shader(platform, renderer)
    if platform == "windows" and renderer:match "direct3d" then
        return true
    elseif platform == "windows" and renderer:match "vulkan" then
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

local function mergeCfgSetting(fx, localpath)
    if fx.setting == nil then
        fx.setting = {}
    elseif type(fx.setting) == "string" then
        fx.setting = serialize.parse(fx.setting, readfile(localpath(fx.setting)))
    else
        assert(type(fx.setting) == "table")
    end

    fx.setting = fxsetting.adddef(fx.setting)
    if fx.cs then
        fx.setting["lighting"]          = 'off'
        fx.setting["shadow_receive"]    = 'off'
    end
end

return function (input, output, setting, localpath)
    local mat = readdatalist(input)
    local fx = mat.fx
    mergeCfgSetting(fx, localpath)
    local depfiles = {
        localpath "/settings"
    }

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
                includes = shader_includes(),
                stage = stage,
                varying_path = varying_path,
                macros = get_macros(setting, mat),
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
