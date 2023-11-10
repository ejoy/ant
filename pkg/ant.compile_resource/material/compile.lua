local lfs           = require "bee.filesystem"
local toolset       = require "material.toolset"
local fxsetting     = require "material.setting"
local shaderparse   = require "material.shaderparse"
local sha1          = require "sha1"

local setting       = import_package "ant.settings"
local serialize     = import_package "ant.serialize"
local vfs_fastio    = require "vfs_fastio"
local depends       = require "depends"
local parallel_task = require "parallel_task"

local matutil       = import_package "ant.material".util
local sa            = import_package "ant.render.core".system_attribs
local ENABLE_SHADOW<const>      = setting:get "graphic/shadow/enable"
local function DEF_FUNC() end

local SHADER_BASE <const> = "/pkg/ant.resources/shaders"

local function shader_includes(include_path)
    local INCLUDE_BASE = lfs.absolute(include_path)
    return {
        lfs.current_path() / SHADER_BASE:sub(2),
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
    cast_shadow = DEF_FUNC,
    no_predepth = DEF_FUNC,
}

local IRRADIANCE_SH_BAND_NUM<const> = setting:get "graphic/ibl/irradiance_bandnum"
local ENABLE_IBL_LUT<const>         = setting:get "graphic/ibl/enable_lut"
local USE_CS_SKINNING<const> = setting:get "graphic/skinning/use_cs"

local enable_cs<const>      = setting:get "graphic/lighting/cluster_shading" ~= 0
local enable_bloom<const>   = setting:get "graphic/postprocess/bloom/enable"
local fxaa_enable<const>   = setting:get "graphic/postprocess/fxaa/enable"
local fxaa_use_green_as_luma<const> = setting:get "graphic/postprocess/fxaa/use_green_as_luma"
local enable_ao<const>      = setting:get "graphic/ao/enable"
local enable_ao_bentnormal<const> = setting:get "graphic/ao/bent_normal"
local ao_qulity<const>      = enable_ao and setting:get "graphic/ao/qulity" or ""

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

    if fxaa_enable and not fxaa_use_green_as_luma then
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

    local state = mat.state
    if state and state.CULL == "NONE" then
        macros[#macros+1] = "WITH_DOUBLE_SIDE=1"
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

local function merge_cfg_setting(setting, fx)
    if fx.setting == nil then
        fx.setting = {}
    elseif type(fx.setting) == "string" then
        fx.setting = serialize.parse(fx.setting, vfs_fastio.readall(setting.vfs, fx.setting))
    else
        assert(type(fx.setting) == "table")
    end

    fx.setting = fxsetting.adddef(setting, fx.setting)
    if fx.cs then
        fx.setting["lighting"]          = 'off'
        fx.setting["shadow_receive"]    = 'off'
    end
end

local DEF_SHADER_INFO <const> = {
    vs = {
        CUSTOM_PROP_KEY = "%$%$CUSTOM_VS_PROP%$%$",
        CUSTOM_FUNC_KEY = "%$%$CUSTOM_VS_FUNC%$%$",
        content = [[
#include "default/inputs_define.sh"

$input a_position a_texcoord0 INPUT_COLOR0 INPUT_NORMAL INPUT_TANGENT INPUT_INDICES INPUT_WEIGHT INPUT_LIGHTMAP_TEXCOORD INPUT_INSTANCE1 INPUT_INSTANCE2 INPUT_INSTANCE3 INPUT_USER0 INPUT_USER1 INPUT_USER2
$output v_texcoord0 OUTPUT_WORLDPOS OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0 OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_BITANGENT OUTPUT_USER0 OUTPUT_USER1 OUTPUT_USER2 OUTPUT_USER3 OUTPUT_USER4

#include "default/inputs_structure.sh"

$$CUSTOM_VS_PROP$$

$$CUSTOM_VS_FUNC$$ 

void main()
{
	VSInput vs_input = (VSInput)0;
	#include "default/vs_inputs_getter.sh"

    VSOutput vs_output = (VSOutput)0;
    CUSTOM_VS_FUNC(vs_input, vs_output);

    #include "default/vs_outputs_getter.sh"
}]],
        filename = "vs_%s.sc",
    },
    fs = {
        CUSTOM_PROP_KEY = "%$%$CUSTOM_FS_PROP%$%$",
        CUSTOM_FUNC_KEY = "%$%$CUSTOM_FS_FUNC%$%$",
        content = [[
#include "default/inputs_define.sh"

$input v_texcoord0 OUTPUT_WORLDPOS OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0 OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_BITANGENT OUTPUT_USER0 OUTPUT_USER1 OUTPUT_USER2 OUTPUT_USER3 OUTPUT_USER4

#include "default/inputs_structure.sh"

$$CUSTOM_FS_PROP$$

$$CUSTOM_FS_FUNC$$

void main()
{
    FSInput fsinput = (FSInput)0;
    #include "default/fs_inputs_getter.sh"

    FSOutput fsoutput = (FSOutput)0;
    CUSTOM_FS_FUNC(fsinput, fsoutput);

    #include "default/fs_outputs_getter.sh"
}]],
        filename = "fs_%s.sc",
    }
}

local function generate_code(content, replacement_key, replacement_content)
    return content:gsub(replacement_key, replacement_content)
end

DEF_SHADER_INFO.vs.default = generate_code(DEF_SHADER_INFO.vs.content, DEF_SHADER_INFO.vs.CUSTOM_FUNC_KEY, [[#include "default/vs_func.sh"]])
DEF_SHADER_INFO.fs.default = generate_code(DEF_SHADER_INFO.fs.content, DEF_SHADER_INFO.fs.CUSTOM_FUNC_KEY, [[#include "default/fs_func.sh"]])

local DEF_PBR_UNIFORM <const> = {
    u_basecolor_factor = {
        shader = "uniform mediump vec4 u_basecolor_factor;",
        attrib = {1, 1, 1, 1},
    },
    u_emissive_factor  = {
        shader = "uniform mediump vec4 u_emissive_factor;",
        attrib = {0, 0, 0, 0},
    },
    u_pbr_factor       ={
        shader = "uniform mediump vec4 u_pbr_factor;",
        attrib = {0, 1, 0, 0} --metalic, roughness, alpha mask, occlusion
    }
}

local ACCESS_NAMES<const> = {
    r = "BUFFER_RO",
    w = "BUFFER_WR",
    rw= "BUFFER_RW",
}

local function which_property_type(n, v)
    if v.stage then
        if v.image or v.texture then
            return "sampler", 1
        end

        assert(v.buffer, "'stage' defined, but not 'image'/'texture'/'buffer'")
        return "buffer", 1
    end

    assert(type(v) == "table")
    if (type(v[1]) == "table") then
        return "uniform", #v
    end
    return "uniform", 1
end

local function which_type(v)
    assert(type(v) == "table")
    if type(v[1]) == "table" then
        return #v[1] == 4 and "vec4" or "mat4"
    end
    return #v == 4 and "vec4" or "mat4"
end

local PROPERTY_TYPES<const> = {
    uniform = {
        shader = function (n, v, num)
            local type = which_type(v)
            -- we cannot set the precision type in our material uniform
            if num > 1 then
                --EX: uniform vec4 name[array_num];
                return ("uniform %s %s[%d];"):format(type, n, num)
            else
                --EX: uniform vec4 name;
                return ("uniform %s %s;"):format(type, n)
            end
        end,
    },
    sampler = {
        shader = function (n, v, num)
            --EX: mediump SAMPLER2D(name, stage)
            return ("%s %s(%s, %d);"):format(
                v.precision or "mediump",
                v.sampler or "SAMPLER2D",
                n, v.stage)
        end,
    },
    buffer = {
        shader = function (n, v, num)
            -- access stage type(default vec4)
            return ("%s(%s, %s, %d);"):format(ACCESS_NAMES[assert(v.access)], n, assert(v.elemtype), assert(v.stage))
        end,
    }
}


local function generate_properties(properties)
    local content = {}
    for name, v in pairs(properties) do
        local st, num = which_property_type(name, v)
        content[#content+1] = assert(PROPERTY_TYPES[st]).shader(name, v, num)
    end
    for k,v in pairs(DEF_PBR_UNIFORM) do
        if not properties[k] then
            content[#content+1] = v.shader
        end
    end
    return table.concat(content, "\n")
end

local function generate_shader(shader, code, properties)
    local updated_shader = code and generate_code(shader.content, shader.CUSTOM_FUNC_KEY, code) or shader.default
    return properties and generate_code(updated_shader, shader.CUSTOM_PROP_KEY, generate_properties(properties)) or updated_shader
end

local function create_PBR_shader(setting, fx, stage, properties)
    local si = assert(DEF_SHADER_INFO[stage])
    local nc = generate_shader(si, fx[stage .. "_code"], properties)
    local fn = si.filename:format(sha1(nc))
    local filename = setting.scpath / fn

    if not lfs.exists(filename) then
        local fw <close> = assert(io.open(filename:string(), "wb"))
        fw:write(nc)
    end
    if fx[stage] then
        error "vs/fs should not define when use genertaed shader"
    end
    fx[stage] = fn
    return filename
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
        -- local function generate_shader_filename(stage)
        --     local codename = stage .. "_code"
        --     if fx[codename] or nil == fx[stage] then
        --         fx[stage] = stage..".sc"
        --     end
        -- end

        -- generate_shader_filename "vs"
        -- generate_shader_filename "fs"
    end
end

local function parent_path(path)
    return path:match "^(.+)/[^/]*$"
end

local function find_varying_path(setting, fx, stage)
    if fx.varying_path then
        return lfs.path(setting.vfs.realpath(fx.varying_path))
    end

    local st = fx.shader_type
    if st == "PBR" then
        return lfs.path(setting.vfs.realpath(SHADER_BASE.."/common/varying_def.sh"))
    end

    if st == "CUSTOM" then
        if setting.vfs.type(parent_path(fx[stage]).."/varying.def.sc") == nil then
            return lfs.path(setting.vfs.realpath(SHADER_BASE.."/common/varying_def.sh"))
        end
    end
end

local CHECK_MT<const> = {__newindex=function () error "DONOT MODIFY" end}

local BgfxOS <const> = {
    macos = "osx",
}

local PBR_SYSTEM_VALUE_STAGES = {}; do
    for n, v in pairs(sa) do
        if ('itb'):match(v.type) then
            PBR_SYSTEM_VALUE_STAGES[v.stage] = n
        end
    end
end

local function read_file(file)
    local f<close> = assert(io.open(file:string(), "rb"))
    return f:read "a"
end

local function is_vec(v) return #v == 4 end

local function to_math_v(v)
	local T = type(v[1])
	if T == 'number' then
		if is_vec(v) then
			return matutil.tv4(v), "v1"
		end
		return matutil.tm4(v), "m1"
	end

	if T == 'table' then
		assert(type(v[1]) == 'table')
		local function from_array(array, op)
			local t = {}
			for _, a in ipairs(array) do
				t[#t+1] = op(a)
			end
			return table.concat(t)
		end

		if is_vec(v[1]) then
			return from_array(v, matutil.tv4), "v" .. #v
		end
		return from_array(v, matutil.tm4), "m" .. #v
	end

	error "Invalid property"
end

local function to_v(t)
	assert(type(t) == "table")
	if t.stage then
        if t.texture then
            t.type = 't'
        elseif t.image then
            t.type = 'i'
            if not t.access or not t.mip then
                error "Image property need define 'access'/'mip'"
            end
        elseif t.buffer then
            t.type = 'b'
            if not t.access then
                error "Image property need define 'access'/'mip'"
            end
        else
            error "Invalid property. Bind resource should define 'texture'/'image'/'buffer' field"
        end
		return t
	end

	assert(not t.index, "not support color palette")

	local value, utype = to_math_v(t)
	return {
        type = 'u',
        value = value,
        utype = utype,
    }
end

local function check_add(systems, name)
    local found
    for _, s in ipairs(systems) do
        if s == name then
            found = true
            break
        end
    end

    if not found then
        systems[#systems+1] = name
    end
end

local function load_shader_uniforms(output, stage, attribs, systems)
    local binfile = output / stage .. ".bin"
    if not lfs.exists(binfile) then
        error(("shader:%s, could not correct build"):format(stage))
    end

    local c = read_file(binfile)
    local s = shaderparse.parse(c)
    for n, v in pairs(s.uniforms) do
        if sa[n] then
            check_add(systems, n)
        else
            attribs[n] = v
        end
    end
end

local UNIFORM_PROPERTY_TYPES<const> = {
    [0] = {
        type = "t",
    },
    [2] = {
        type = "u",
        utype = "v",
    },
    -- 3 for mat3, not support right now
    -- [3] = {
    --     type = "u",
    --     utype = "m",
    -- },
    [4] = {
        type = "u",
        utype = "m",
    }
}

local DEFAULT_UNIFORM_VALUES = setmetatable({}, {__index=function (tt, k) 
    local t, n = k:match "([vm])(%d+)"
    local e = t == "v" and matutil.ZERO or matutil.IDENTITY_MAT
    local v = e:rep(n)
    tt[k] = v
    return v
end})

local function default_uniform_from_shader(u)
    local t = assert(UNIFORM_PROPERTY_TYPES[u.type], "Invalid uniform type from shader")
    if t.type == "u" then
        local utype = t.utype .. (u.num > 0 and u.num or "1")
        return {
            type  = t.type,
            utype = utype,
            value = DEFAULT_UNIFORM_VALUES[utype],
        }
    elseif t.type == "t" then
        return {
            type = t.type,
            stage = 0,
        }
    else
        error "Invalid type"
    end

end

local function check_material_properties(properties, shaderuniforms)
    for n, v in pairs(shaderuniforms) do
        local p = properties[n]
        if p then
            if sa[n] then
                error(("Property:%s, same name with system value"):format(n))
            end

            if p.stage and PBR_SYSTEM_VALUE_STAGES[p.stage] then
                error(("Invalid property:%s, use a system value:%s, stage:%d"):format(n, PBR_SYSTEM_VALUE_STAGES[p.stage], p.stage))
            end
            shaderuniforms[n] = to_v(p)
        else
            shaderuniforms[n] = default_uniform_from_shader(v)
        end
    end

    -- buffer/image properties will be add to shader binary file, we need to add buffer property from material file
    for n, v in pairs(properties) do
        if not shaderuniforms[n] and (v.buffer or v.image) then
            local stage = assert(v.stage)
            if PBR_SYSTEM_VALUE_STAGES[stage] then
                error(("Buffer/image property:%s use a system value:%s stage:%d"):format(n, PBR_SYSTEM_VALUE_STAGES[stage], stage))
            end
            shaderuniforms[n] = {
                type    = v.image and 'i' or 'b',
                stage   = stage,
                access  = assert(v.access),
                mip     = v.mip,
                sampler = v.sampler,
            }
        end
    end
end

local function build_properties(matproperties, shadertype)
    local properties = {}
    --copy properties
    if matproperties then
        for k, v in pairs(matproperties) do
            properties[k] = v
        end
    end
    if shadertype == "PBR" then
        for n, v in pairs(DEF_PBR_UNIFORM) do
            if not properties[n] then
                properties[n] = v.attrib
            end
        end
    end
    return properties
end

local function add_lighting_sv(systems, lighting)
    if lighting == "on" then
        systems[#systems+1] = "b_light_info"
        if enable_cs then
            systems[#systems+1] = "b_light_grids"
            systems[#systems+1] = "b_light_index_lists"
        end
    end
end

local function compile(tasks, post_tasks, deps, mat, input, output, setting)
    depends.add_vpath(deps, setting, "/pkg/ant.compile_resource/material/version.lua")
    depends.add_vpath(deps, setting, "/pkg/ant.settings/default/graphic.settings")
    depends.add_vpath(deps, setting, "/graphic.settings")

    local include_path = lfs.path(input):parent_path()
    lfs.remove_all(output)
    lfs.create_directories(output)
    local fx = mat.fx
    merge_cfg_setting(setting, fx)
    check_update_fx(fx)
    -- setmetatable(fx, CHECK_MT)
    -- setmetatable(fx.setting, CHECK_MT)
    local function compile_shader(stage)
        parallel_task.add(tasks, function ()
            local inputpath; do
                if fx.shader_type == "PBR" then
                    inputpath = create_PBR_shader(setting, fx, stage, mat.properties)
                else
                    local lpath = setting.vfs.realpath(fx[stage])
                    if lpath == nil then
                        error(("shader path not exists: %s"):format(fx[stage]))
                    end
                    inputpath = lfs.path(lpath)
                end
            end


            local ok, res = toolset.compile {
                platform    = BgfxOS[setting.os] or setting.os,
                renderer    = setting.renderer,
                input       = inputpath,
                output      = output / (stage..".bin"),
                includes    = shader_includes(include_path),
                stage       = stage,
                varying_path= find_varying_path(setting, fx, stage),
                macros      = get_macros(setting, mat),
                debug       = compile_debug_shader(setting.os, setting.renderer),
                setting     = setting,
            }
            if not ok then
                error("compile failed: " .. output:string() .. "\n" .. res)
            end
            depends.append(deps, res)
        end)
    end

    local function create_shader_cfg(stages)
        parallel_task.add(post_tasks, function ()
            local attribs, systems = {}, {}
            for _, stage in ipairs(stages) do
                load_shader_uniforms(output, stage, attribs, systems)
            end
            add_lighting_sv(systems, fx.setting.lighting)

            local properties = build_properties(mat.properties, fx.shader_type)
            check_material_properties(properties, attribs)

            local outfile = output / "main.attr"
            writefile(outfile, {attrib = attribs, system=systems})
        end)

        --some info write to 'mat' in tasks, we should write 'main.cfg' here
        parallel_task.add(post_tasks, function ()
            writefile(output / "main.cfg",  mat)
        end)
    end

    if fx.shader_type == "COMPUTE" then
        compile_shader "cs"
        create_shader_cfg {"cs"}
    else
        local stages = {"vs"}
        compile_shader "vs"
        local function has_fs()
            return fx.fs or fx.shader_type == "PBR"
        end
        if has_fs() then
            compile_shader "fs"
            stages[#stages+1] = "fs"
        end

        create_shader_cfg(stages)
    end
end

return compile
