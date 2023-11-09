local lfs           = require "bee.filesystem"
local fs            = require "filesystem"

local toolset       = require "material.toolset"
local fxsetting     = require "material.setting"
local shaderparse   = require "material.shaderparse"
local genshader     = require "material.genshader"

local settings      = import_package "ant.settings"
local serialize     = import_package "ant.serialize"
local vfs_fastio    = require "vfs_fastio"
local depends       = require "depends"
local parallel_task = require "parallel_task"

local matutil       = import_package "ant.material".util
local sa            = import_package "ant.render.core".system_attribs

local ENABLE_SHADOW<const>          = settings:get "graphic/shadow/enable"
local IRRADIANCE_SH_BAND_NUM<const> = settings:get "graphic/ibl/irradiance_bandnum"
local ENABLE_IBL_LUT<const>         = settings:get "graphic/ibl/enable_lut"
local USE_CS_SKINNING<const>        = settings:get "graphic/skinning/use_cs"

local ENABLE_CS<const>              = settings:get "graphic/lighting/cluster_shading" ~= 0
local ENABLE_BLOOM<const>           = settings:get "graphic/postprocess/bloom/enable"
local ENABLE_FXAA<const>            = settings:get "graphic/postprocess/fxaa/enable"
local FXAA_USE_GREEN_AS_LUMA<const> = settings:get "graphic/postprocess/fxaa/use_green_as_luma"
local ENABLE_AO<const>              = settings:get "graphic/ao/enable"
local ENABLE_AO_BENT_NORMAL<const>  = settings:get "graphic/ao/bent_normal"
local AO_QULITY<const>              = ENABLE_AO and settings:get "graphic/ao/qulity" or ""

local function DEF_FUNC() end

local LOCAL_SHADER_BASE<const>      = genshader.LOCAL_SHADER_BASE
local VARYING_DEFAULT_PATH<const>   = LOCAL_SHADER_BASE / "common/varying_def.sh"

local function shader_includes(include_path)
    return {
        LOCAL_SHADER_BASE,
        lfs.absolute(include_path),
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

local DEFAULT_MACROS; do
    DEFAULT_MACROS = {
        "ENABLE_SRGB_TEXTURE=1",
        "ENABLE_SRGB_FB=1",
        "ENABLE_IBL=1",
        "ENABLE_TEXTURE_GATHER=1",
    }

    if ENABLE_CS then
        DEFAULT_MACROS[#DEFAULT_MACROS+1] = "CLUSTER_SHADING=1"
    end

    if ENABLE_BLOOM then
        DEFAULT_MACROS[#DEFAULT_MACROS+1] = "BLOOM_ENABLE=1"
    end

    if ENABLE_AO then
        DEFAULT_MACROS[#DEFAULT_MACROS+1] = "ENABLE_SSAO=1"
        if ENABLE_AO_BENT_NORMAL then
            DEFAULT_MACROS[#DEFAULT_MACROS+1] = "ENABLE_BENT_NORMAL=1"
        end

        if AO_QULITY == "high" then
            DEFAULT_MACROS[#DEFAULT_MACROS+1] = "HIGH_QULITY_SPECULAR_AO=1"
            DEFAULT_MACROS[#DEFAULT_MACROS+1] = "HIGH_QULITY_NORMAL_RECONSTRUCT=1"
        end
    end

    if ENABLE_FXAA and not FXAA_USE_GREEN_AS_LUMA then
        DEFAULT_MACROS[#DEFAULT_MACROS+1] = "COMPUTE_LUMINANCE_TO_ALPHA=1"
    end

    if IRRADIANCE_SH_BAND_NUM then
        DEFAULT_MACROS[#DEFAULT_MACROS+1] = "IRRADIANCE_SH_BAND_NUM=" .. IRRADIANCE_SH_BAND_NUM
    end

    if USE_CS_SKINNING then
        DEFAULT_MACROS[#DEFAULT_MACROS+1] = "CS_SKINNING=1"
    end

    if ENABLE_IBL_LUT then
        DEFAULT_MACROS[#DEFAULT_MACROS+1] = "ENABLE_IBL_LUT=1"
    end
end

local function default_macros(setting)
    local m = {
        "HOMOGENEOUS_DEPTH=" .. (setting.hd and "1" or "0"),
        "ORIGIN_BOTTOM_LEFT=" .. (setting.obl and "1" or "0"),
    }
    table.move(DEFAULT_MACROS, 1, #DEFAULT_MACROS, #m+1, m)
    return m
end

local function get_macros(setting, mat, others)
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
    if others then
        table.move(others, 1, #others, #macros+1, macros)
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

local function find_varying_path(fx, stage)
    if fx.varying_path then
        return lfs.path(setting.vfs.realpath(fx.varying_path))
    end

    local st = fx.shader_type
    if st == "PBR" then
        return VARYING_DEFAULT_PATH
    end

    if st == "CUSTOM" then
        if setting.vfs.type(parent_path(fx[stage]).."/varying.def.sc") == nil then
            return VARYING_DEFAULT_PATH
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
        for n, v in pairs(genshader.DEF_PBR_UNIFORM) do
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
        if ENABLE_CS then
            systems[#systems+1] = "b_light_grids"
            systems[#systems+1] = "b_light_index_lists"
        end
    end
end

local function compile(tasks, post_tasks, deps, mat, input, output, setting)
    depends.add_vpath(deps, setting, "/pkg/ant.compile_resource/material/version.lua")
    depends.add_vpath(deps, setting, "/pkg/ant.settings/default/graphic.settings")
    depends.add_vpath(deps, setting, "/graphic.settings")

    local inputfolder = lfs.path(input):parent_path()
    lfs.remove_all(output)
    lfs.create_directories(output)
    local fx = mat.fx
    merge_cfg_setting(setting, fx)
    check_update_shader_type(fx)
    -- setmetatable(fx, CHECK_MT)
    -- setmetatable(fx.setting, CHECK_MT)
    local pbrfx, pbrmacros
    if fx.shader_type == "PBR" then
        pbrfx, pbrmacros = genshader.gen_fx(setting, inputfolder, output, mat)
    end
    local function compile_shader(stage)
        parallel_task.add(tasks, function ()
            local inputfile = fx.shader_type == "PBR" and
                genshader.gen_shader(setting, fx, stage, pbrfx) or
                lfs.path(setting.vfs.realpath(fx[stage]))

            if not lfs.exists(inputfile) then
                error(("shader path not exists: %s"):format(inputfile:string()))
            end


            local ok, res = toolset.compile {
                platform    = BgfxOS[setting.os] or setting.os,
                renderer    = setting.renderer,
                input       = inputfile,
                output      = output / (stage..".bin"),
                includes    = shader_includes(inputfolder),
                stage       = stage,
                varying_path= find_varying_path(setting, fx, stage),
                macros      = get_macros(setting, mat, pbrmacros),
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

    local stages = {}
    if fx.shader_type == "COMPUTE" then
        compile_shader "cs"
        stages[#stages+1] = "cs"
    else
        compile_shader "vs"
        stages[#stages+1] = "vs"

        local function has_fs()
            return fx.fs or fx.shader_type == "PBR"
        end
        if has_fs() then
            compile_shader "fs"
            stages[#stages+1] = "fs"
        end
    end

    create_shader_cfg(stages)
end

return compile
