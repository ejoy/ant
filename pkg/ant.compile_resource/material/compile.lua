local lfs           = require "bee.filesystem"
local ltask         = require "ltask"
local datalist      = require "datalist"

local toolset       = require "material.toolset"
local fxsetting     = require "material.setting"
local shaderparse   = require "material.shaderparse"
local genshader     = require "material.genshader"

local settings      = import_package "ant.settings"
local serialize     = import_package "ant.serialize"
local vfs_fastio    = require "vfs_fastio"
local depends       = require "depends"

local matutil       = import_package "ant.material".util
local sa            = import_package "ant.render.core".system_attribs

local L             = import_package "ant.render.core".layout

local IRRADIANCE_SH_BAND_NUM<const> = settings:get "graphic/ibl/irradiance_bandnum"
local ENABLE_IBL_LUT<const>         = settings:get "graphic/ibl/enable_lut"
local USE_CS_SKINNING<const>        = settings:get "graphic/skinning/use_cs"

local ENABLE_CS<const>              = settings:get "graphic/lighting/cluster_shading/enable"
local ENABLE_BLOOM<const>           = settings:get "graphic/postprocess/bloom/enable"
local ENABLE_FXAA<const>            = settings:get "graphic/postprocess/fxaa/enable"
local FXAA_USE_GREEN_AS_LUMA<const> = settings:get "graphic/postprocess/fxaa/use_green_as_luma"
local ENABLE_AO<const>              = settings:get "graphic/ao/enable"
local ENABLE_AO_BENT_NORMAL<const>  = settings:get "graphic/ao/bent_normal"
local AO_QULITY<const>              = ENABLE_AO and settings:get "graphic/ao/qulity" or ""

local LOCAL_SHADER_BASE<const>      = genshader.LOCAL_SHADER_BASE
local VARYING_DEFAULT_PATH<const>   = LOCAL_SHADER_BASE / "common/varying_def.sh"

local function shader_includes(include_path)
    return {
        LOCAL_SHADER_BASE,
        lfs.absolute(include_path),
    }
end

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


local CHECK_SETTING
do
    local VALID_SETTINGS<const> = {
        lighting        = true,
        cast_shadow     = true,
        receive_shadow  = true,
        subsurface      = true,
        uv_motion       = true,
        position_only   = true,
        no_predepth     = true,
        no_skinning     = true,
        threadsize      = true,
    }

    function CHECK_SETTING(mat, macros)
        local s = mat.fx.setting
        for k in pairs(s) do
            if not VALID_SETTINGS[k] then
                error(("Field: %s in fx.setting is not allow"):format(k))
            end
        end

        if mat.fx.shader_type ~= "PBR" then
            genshader.macros_from_setting(mat.fx.setting, macros)
        end
    end
end

local function remove_duplicate_macros(macros)
    local marks = {}
    for _, m in ipairs(macros) do
        local n, v = m:match "([%w_]+)=([%dx]+)"
        if not n or not v then
            error(("Invalid macro define:%s, it should be 'name'='value'"):format(m))
        end
        if marks[n] then
            log.warn(("Multi define macro, use the latest one, name:%s, value%d, last value:%d"):format(n, v, marks[n]))
        end
        marks[n] = v
    end

    local function sortpairs(t)
        local sort = {}
        for k in pairs(t) do
            sort[#sort+1] = k
        end
        table.sort(sort)
        local n = 1
        return function ()
            local k = sort[n]
            if k == nil then
                return
            end
            n = n + 1
            return k, t[k]
        end
    end

    local mm = {}
    for n, v in sortpairs(marks) do
        mm[#mm+1] = ("%s=%s"):format(n, v)
    end

    return mm
end

local function get_macros(setting, mat, stage)
    local macros = default_macros(setting)
    CHECK_SETTING(mat, macros)
    if mat.fx.macros then
        if #mat.fx.macros == 0 and nil ~= next(mat.fx.macros) then
            error("material-macros feild should use the format: '{macro_name}={value}', like 'ENABLE_SHADOW=1', DO NOT use 'ENABLE_SHADOW: 1'")
        end
        table.move(mat.fx.macros, 1, #mat.fx.macros, #macros+1, macros)
    end
    if stage:match "di" then
        macros[#macros+1] = "DRAW_INDIRECT=1"
    end
    return remove_duplicate_macros(macros)
end

local function compile_debug_shader(platform, renderer)
    --TODO: bgfx does not support metal/vulkan compilation as debug
    if platform == "windows" then
        if renderer:match "direct3d" then
            return true
        end
    end
end

local function writefile(filename, data)
	local f <close> = assert(io.open(filename:string(), "wb"))
	f:write(serialize.stringify(data))
end

local function merge_cfg_setting(setting, fx)
    if fx.setting == nil then
        fx.setting = {}
    elseif type(fx.setting) == "string" then
        fx.setting = datalist.parse(vfs_fastio.readall_f(setting.vfs, fx.setting))
    else
        assert(type(fx.setting) == "table")
    end

    fx.setting = fxsetting.adddef(setting, fx.setting)
    if fx.cs then
        fx.setting["lighting"]          = 'off'
        fx.setting["receive_shadow"]    = 'off'
        fx.setting["cast_shadow"]       = 'off'
    else
        local lighting = assert(fx.setting.lighting)
        if lighting == "off" then
            fx.setting["receive_shadow"]    = 'off'
            fx.setting["cast_shadow"]       = 'off'
        end
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
            if fx.vs_code or fx.fs_code then
                fx.shader_type = "PBR"
            else
                fx.shader_type = "CUSTOM"
            end
        else
            if fx.shader_type == "CUSTOM" and (fx.vs_code or fx.fs_code) then
                error "Define shader_type as 'CUSTOM', 'vs_code' or 'fs_code' should not define"
            end
            assert(fx.shader_type == "PBR" or fx.shader_type == "CUSTOM", "render shader 'shader_type' should only be 'PBR' or 'CUSTOM'")
        end
    end
end

local function parent_path(path)
    return path:match "^(.+)/[^/]*$"
end

local function find_varying_path(setting, fx, stage)
    local path = stage:match "di" and "di_varying_path" or "varying_path"
    
    if fx[path] then
        local p = lfs.path(setting.vfs.realpath(fx[path]) or fx[path])
        if not lfs.exists(p) then
            error(("Invalid varying path:%s"):format(fx[path]))
        end
        return p
    end

    if fx.shader_type == "CUSTOM" then
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

local function load_shader_uniforms(setting, output, stage, ao)
    local attribs, systems = ao.attribs, ao.systems
    local binfile = output / stage .. ".bin"
    if not lfs.exists(binfile) then
        error(("shader:%s, could not correct build"):format(stage))
    end

    local c = read_file(binfile)
    local s = shaderparse.parse(c, setting.renderer)
    for n, v in pairs(s.uniforms) do
        if sa[n] then
            check_add(systems, n)
        else
            attribs[n] = v
        end
    end

    return s
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

local function add_lighting_sv(systems, lighting)
    if lighting == "on" then
        systems[#systems+1] = "b_light_info"
        if ENABLE_CS then
            systems[#systems+1] = "b_light_grids"
            systems[#systems+1] = "b_light_index_lists"
        end
    end
end

local STAGES<const> = {
    vs = "vs",
    fs = "fs",
    cs = "cs",
    depth = "vs",
    di = "vs"
}

local function find_stage_file(setting, fx, stage)
    local inputfile
    local stagefile = fx[stage]
    if stagefile then
        -- stage file can be local path
        inputfile = lfs.path(setting.vfs.realpath(stagefile) or stagefile)
    end

    if (not inputfile) or not lfs.exists(inputfile) then
        error(("shader path not exists: %s, stage:%s"):format(fx[stage], stage))
    end

    return inputfile
end

local function check_vs_inputs(setting, inputfolder, mat, inputs)
    local varyings = genshader.read_varyings(setting, inputfolder, mat.fx)
    if varyings and inputs then
        for _, input in ipairs(inputs) do
            local function check_is_instance_data()
                for i=0, 4 do
                    local idata = "i_data" .. i
                    if varyings[idata] and L.SEMANTICS_INFOS[idata].bind == L.SEMANTICS_INFOS[input].bind then
                        return true
                    end
                end
            end

            if (not varyings[input]) and (not check_is_instance_data()) then

                error(("Shader need input: %s, but material varyings not provided"):format(input))
            end
        end
    end
end

local function create_shader_cfg(setting, inputfolder, output, mat, stages)
    local lighting<const>   = mat.fx.setting.lighting
    local properties<const> = mat.properties or {}
    local function attrib_obj()
        return {attribs={}, systems={}}
    end

    local ao = attrib_obj()
    if stages.cs then
        assert(stages.vs == nil and stages.fs == nil and stages.depth == nil)
        load_shader_uniforms(setting, output, "cs", ao)
    else
        if stages.vs then
            local s = load_shader_uniforms(setting, output, "vs", ao)
            check_vs_inputs(setting, inputfolder, mat, s.inputs)
        end
        if stages.fs then
            load_shader_uniforms(setting, output, "fs", ao)
        end
    end

    add_lighting_sv(ao.systems, lighting)
    check_material_properties(properties, ao.attribs)
    if stages.depth then
        ao.depth = attrib_obj()
        load_shader_uniforms(setting, output, "depth", ao.depth)
        check_material_properties(properties, ao.depth.attribs)
    end

    if stages.di then
        ao.di = attrib_obj()
        load_shader_uniforms(setting, output, "di", ao.di)
        check_material_properties(properties, ao.di.attribs)
    end

    local outfile = output / "attribute.ant"
    writefile(outfile, ao)
end

local function compile(deps, mat, input, output, setting)
    depends.add_vpath(deps, setting, "/pkg/ant.compile_resource/material/version.lua")
    depends.add_vpath(deps, setting, "/pkg/ant.settings/default/graphic_settings.ant")
    depends.add_vpath(deps, setting, "/graphic_settings.ant")

    local inputfolder = lfs.path(input):parent_path()
    lfs.remove_all(output)
    lfs.create_directories(output)

    local fx = mat.fx
    merge_cfg_setting(setting, fx)
    check_update_shader_type(fx)

    local stages = genshader.gen_fx(setting, input, output, mat)
    writefile(output / "source.ant",  mat)

    local function compile_shader(stage)
        local ok, res = toolset.compile {
            platform    = BgfxOS[setting.os] or setting.os,
            renderer    = setting.renderer,
            input       = find_stage_file(setting, fx, stage),
            output      = output / (stage..".bin"),
            includes    = shader_includes(inputfolder),
            stage       = assert(STAGES[stage]),
            varying_path= find_varying_path(setting, fx, stage),
            macros      = get_macros(setting, mat, stage),
            debug       = compile_debug_shader(setting.os, setting.renderer),
            setting     = setting,
        }
        if not ok then
            error("compile failed: " .. output:string() .. "\n" .. res)
        end
        depends.append(deps, res)
    end

    local t = {}
    for stage in pairs(stages) do
        t[#t+1] = { compile_shader, stage }
    end
    if #t == 1 then
        local stage = t[1][2]
        compile_shader(stage)
    else
        for _, resp in ltask.parallel(t) do
            if resp.error then
                resp:rethrow()
            end
        end
    end
    create_shader_cfg(setting, inputfolder, output, mat, stages)
end

return compile
