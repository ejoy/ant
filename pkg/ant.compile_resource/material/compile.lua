local lfs           = require "bee.filesystem"
local fs            = require "filesystem"
local fastio        = require "fastio"
local toolset       = require "material.toolset"
local fxsetting     = require "material.setting"
local setting       = import_package "ant.settings".setting
local serialize     = import_package "ant.serialize"
local depends       = require "depends"
local parallel_task = require "parallel_task"

local ENABLE_SHADOW<const>      = setting:get "graphic/shadow/enable"

local function DEF_FUNC() end

local SHADER_BASE<const>            = lfs.absolute(fs.path "/pkg/ant.resources/shaders":localpath())
local function shader_includes(include_path)
    local INCLUDE_BASE = lfs.absolute(include_path)
    return {
        SHADER_BASE,
        INCLUDE_BASE
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
    no_predepth = DEF_FUNC,
}

local IRRADIANCE_SH_BAND_NUM<const> = setting:get "graphic/ibl/irradiance_bandnum"
local ENABLE_IBL_LUT<const>         = setting:get "graphic/ibl/enable_lut"
local USE_CS_SKINNING<const> = setting:get "graphic/skinning/use_cs"

local enable_cs<const>      = setting:get "graphic/lighting/cluster_shading" ~= 0
local enable_bloom<const>   = setting:get "graphic/postprocess/bloom/enable"
local fxaa_setting<const>   = setting:data().graphic.postprocess.fxaa
local enable_ao<const>      = setting:get "graphic/ao/enable"
local enable_ao_bentnormal<const> = setting:get "graphic/ao/bent_normal"
local ao_qulity<const>      = enable_ao and setting:get "graphic/ao/qulity" or ""

-- local curve_world = setting:data().graphic.curve_world
-- local curve_world_type_macros<const> = {
--     view_sphere = 1,
--     cylinder = 2,
-- }

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

    -- if curve_world.enable then
    --     m[#m+1] = "ENABLE_CURVE_WORLD=" .. curve_world_type_macros[curve_world.type]
    -- end

    if enable_bloom then
        m[#m+1] = "BLOOM_ENABLE=1"
    end

    if enable_ao then
        m[#m+1] = "ENABLE_SSAO=1"
        if enable_ao_bentnormal then
            m[#m+1] = "ENABLE_BENT_NORMAL=1"
        end

        if ao_qulity == "high" then
            m[#m+1] = "HIGH_QULITY_SPECULAR_AO=1"
            m[#m+1] = "HIGH_QULITY_NORMAL_RECONSTRUCT=1"
        end
    end

    if fxaa_setting.enable and not fxaa_setting.use_green_as_luma then
        m[#m+1] = "COMPUTE_LUMINANCE_TO_ALPHA=1"
    end

    if IRRADIANCE_SH_BAND_NUM then
        m[#m+1] = "IRRADIANCE_SH_BAND_NUM=" .. IRRADIANCE_SH_BAND_NUM
        m[#m+1] = "IRRADIANCE_SH_BAND_NUM=" .. IRRADIANCE_SH_BAND_NUM
    end

    if USE_CS_SKINNING then
        m[#m+1] = "CS_SKINNING=1"
    end

    if ENABLE_IBL_LUT then
        m[#m+1] = "ENABLE_IBL_LUT=1"
    end

    return m
end

local PBR_TEXTURE_MACROS<const> = {
    s_basecolor             = "HAS_BASECOLOR_TEXTURE=1",
    s_normal                = "HAS_NORMAL_TEXTURE=1",
    s_metallic_roughness    ="HAS_METALLIC_ROUGHNESS_TEXTURE=1",
    s_emissive              ="HAS_EMISSIVE_TEXTURE=1",
    s_occlusion             ="HAS_OCCLUSION_TEXTURE=1",
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

    local st = assert(mat.fx.shader_type)
    if st == "PBR" then
        local properties = mat.properties
        if properties then
            for texname, m in pairs(PBR_TEXTURE_MACROS) do
                if properties[texname] then
                    macros[#macros+1] = m
                end
            end
        end
    end
    table.sort(macros)
	return macros
end

local function compile_debug_shader(platform, renderer)
    return platform == "windows" and (renderer:match "direct3d" or renderer:match "vulkan")
end

local function writefile(filename, data)
	local f <close> = assert(io.open(filename:string(), "wb"))
	f:write(serialize.stringify(data))
end

local function merge_cfg_setting(fx, localpath)
    if fx.setting == nil then
        fx.setting = {}
    elseif type(fx.setting) == "string" then
        fx.setting = serialize.parse(fx.setting, fastio.readall(localpath(fx.setting):string()))
    else
        assert(type(fx.setting) == "table")
    end

    fx.setting = fxsetting.adddef(fx.setting)
    if fx.cs then
        fx.setting["lighting"]          = 'off'
        fx.setting["shadow_receive"]    = 'off'
    end
end

local DEF_VARYING_FILE<const> = SHADER_BASE / "common/varying_def.sh"

local function generate_code(content, replacement_key, replacement_content)
    return content:gsub(replacement_key, replacement_content)
end

local DEF_SHADER_INFO<const> = {
    vs = {
        CUSTOM_PROP_KEY = "%$%$CUSTOM_VS_PROP%$%$",
        CUSTOM_FUNC_KEY = "%$%$CUSTOM_VS_FUNC%$%$",
        content = fastio.readall_s((SHADER_BASE / "default/vs_default.sc"):string()),
    },
    fs = {
        CUSTOM_PROP_KEY = "%$%$CUSTOM_FS_PROP%$%$",
        CUSTOM_FUNC_KEY = "%$%$CUSTOM_FS_FUNC%$%$",
        content = fastio.readall_s((SHADER_BASE / "default/fs_default.sc"):string()),
    }
}

DEF_SHADER_INFO.vs.default = generate_code(DEF_SHADER_INFO.vs.content, DEF_SHADER_INFO.vs.CUSTOM_FUNC_KEY, [[#include "default/vs_func.sh"]])
DEF_SHADER_INFO.fs.default = generate_code(DEF_SHADER_INFO.fs.content, DEF_SHADER_INFO.fs.CUSTOM_FUNC_KEY, [[#include "default/fs_func.sh"]])

local DEF_PBR_UNIFORM = {
    u_basecolor_factor = "uniform mediump vec4 u_basecolor_factor;",
    u_emissive_factor  = "uniform mediump vec4 u_emissive_factor;",
    u_pbr_factor       = "uniform mediump vec4 u_pbr_factor;"
}
local function generate_properties(properties)
    local content = {}
    for k, v in pairs(properties) do
        local result
        if k:find("s_") == 1 then
            -- precision(default mediump) / sampler(default SAMPLER2D) / stage 
            local precision = v.precision or "mediump"
            local sampler = v.sampler or "SAMPLER2D"
            local stage = v.stage
            if v.image then assert(v.mip, "image format should config mipmap level! \n") end
            assert(stage, "texture must config stage! \n")
            result = string.format("%s %s(%s, %d);", precision, sampler, k, stage)
        elseif k:find("u_") == 1 then
            -- precision(default mediump) type(default vec4)
            local precision = v.precsion or "mediump"
            local type = v.type or "vec4"
            result = string.format("%s %s %s %s;", "uniform", precision, type, k)
        elseif k:find("b_") == 1 then
            -- access stage type(default vec4)
            local access, stage, buffer_access = v.access, v.stage, nil
            local type = v.type or "vec4"
            assert(access and stage, "buffer must config access and stage! \n")
            if stage == 'r' then buffer_access = "BUFFER_RO"
            elseif stage == 'w' then buffer_access = "BUFFER_WR"
            else log.error("wrong access type, access should be read/write! \n") end
            result = string.format("%s(%s, %s, %d);", buffer_access, k, type, stage)
        else
            error(("wrong property name:%s, property should be sampler/uniform/buffer!"):format(k))
        end
        content[#content+1] = result
    end
    for k,v in pairs(DEF_PBR_UNIFORM) do
        if not properties[k] then
            content[#content+1] = v
        end
    end
    return table.concat(content, "\n")
end

local function generate_shader(shader, code, properties)
    local updated_shader = code and generate_code(shader.content, shader.CUSTOM_FUNC_KEY, code) or shader.default
    return properties and generate_code(updated_shader, shader.CUSTOM_PROP_KEY, generate_properties(properties)) or updated_shader
end

local function create_PBR_shader(inputpath, fx, stage, properties)
    local si = assert(DEF_SHADER_INFO[stage])
    local nc = generate_shader(si, fx[stage .. "_code"], properties)

    local fw <close> = assert(io.open(inputpath:string(), "wb"))
    fw:write(nc)
end

--[[
    shader_type:
    COMPUTE:    only for compute shader, fx.cs must define
    PBR:        use /pkg/ant.resources/shaders/dynamic_material/vs_default.sc|fs_default.sc shaders, and use [vs|fs]_code to modify the final shader(can be 'nil'), that generated shader will save as ./[vs|fs].sc
    CUSTOM:     use user defined vs/fs file
]]

local function check_update_shader_type(fx)
    if fx.cs then
        if fx.shader_type then
            assert(fx.shader_type == "COMPUTE", "compute shader 'shader_type' should only be 'COMPUTE'")
        else
            fx.shader_type = "COMPUTE"
        end
    else
        if fx.shader_type == nil then
            if fx.vs or fx.fs then
                fx.shader_type = "CUSTOM"
            else
                fx.shader_type = "PBR"
            end
        else
            assert(fx.shader_type == "PBR" or fx.shader_type == "CUSTOM", "render shader 'shader_type' should only be 'PBR' or 'CUSTOM'")
        end
    end
end

local function check_update_fx(fx)
    check_update_shader_type(fx)
    local st = assert(fx.shader_type, "Invalid fx, could not find valid 'shader_type' or 'shader_type' not defined")
    if st == "PBR" then
        local function generate_shader_filename(stage)
            local codename = stage .. "_code"
            if fx[codename] or nil == fx[stage] then
                fx[stage] = stage..".sc"
            end
        end

        generate_shader_filename "vs"
        generate_shader_filename "fs"
    end
end

local function find_varying_path(fx, stage, localpath)
    if fx.varying_path then
        return localpath(fx.varying_path)
    end

    local st = fx.shader_type
    if st == "PBR" then
        return DEF_VARYING_FILE
    end

    if st == "CUSTOM" then
        local filepath = fs.path(fx[stage])
        if not fs.exists(filepath:parent_path() / "varying.def.sc") then
            return DEF_VARYING_FILE
        end
    end
end

local CHECK_MT<const> = {__newindex=function () error "DONOT MODIFY" end}

local BgfxOS <const> = {
    macos = "osx",
}

local function compile(tasks, deps, mat, input, output, setting, localpath)
    local include_path = lfs.path(input):parent_path()
    lfs.remove_all(output)
    lfs.create_directories(output)
    local fx = mat.fx
    merge_cfg_setting(fx, localpath)
    check_update_fx(fx)

    setmetatable(fx, CHECK_MT)
    setmetatable(fx.setting, CHECK_MT)

    writefile(output / "main.cfg", mat)

    local function compile_shader(stage)
        parallel_task.add(tasks, function ()
            local inputpath = fx[stage]
            local varying_path = find_varying_path(fx, stage, localpath)
            if fx.shader_type == "PBR" then
                inputpath = output / inputpath
                create_PBR_shader(inputpath, fx, stage, mat.properties)
            else
                inputpath = localpath(inputpath)
            end
        
            if not lfs.exists(inputpath) then
                error(("shader path not exists: %s"):format(inputpath:string()))
            end
        
            local ok, res = toolset.compile {
                platform = BgfxOS[setting.os] or setting.os,
                renderer = setting.renderer,
                input = inputpath,
                output = output / (stage..".bin"),
                includes = shader_includes(include_path),
                stage = stage,
                varying_path = varying_path,
                macros = get_macros(setting, mat),
                debug = compile_debug_shader(setting.os, setting.renderer),
            }
            if not ok then
                error("compile failed: " .. output:string() .. "\n" .. res)
            end
            depends.append(deps, res)
        end)
    end

    if fx.shader_type == "COMPUTE" then
        compile_shader "cs"
    else
        compile_shader "vs"
        if fx.fs then
            compile_shader "fs"
        end
    end
end

return compile
