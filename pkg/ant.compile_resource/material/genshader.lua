local sha1          = require "sha1"
local lfs           = require "bee.filesystem"
local datalist      = require "datalist"
local lfastio       = require "fastio"

local LOCAL_SHADER_BASE <const> = lfs.current_path() / "pkg/ant.resources/shaders"

local DEF_SHADER_INFO <const> = {
    vs = {
        defines = {
            VARYING_DEFINE      = "@VSINPUT_VARYING_DEFINE",
            INPUTOUTPUT_STRUCT  = "@VSINPUTOUTPUT_STRUCT",
    
            PROPERTY_DEFINE     = "@VS_PROPERTY_DEFINE",
            FUNC_DEFINE         = "@VS_FUNC_DEFINE",
    
            INPUT_INIT          = "@VSINPUT_INIT",
            OUTPUT_VARYINGS     = "@OUTPUT_VARYINGS",
        },
        template                = lfastio.readall_s((LOCAL_SHADER_BASE / "default/vs_default.sc"):string()),
        filename                = "vs_%s.sc",
    },
    fs = {
        defines = {
            VARYING_DEFINE      = "@FSINPUT_VARYINGS_DEFINE",
            INPUTOUTPUT_STRUCT  = "@FSINPUTOUTPUT_STRUCT",
    
            PROPERTY_DEFINE     = "@FS_PROPERTY_DEFINE",
            FUNC_DEFINE         = "@FS_FUNC_DEFINE",
    
            INPUT_INIT          = "@FSINPUT_INIT",
        },
        template                = lfastio.readall_s((LOCAL_SHADER_BASE / "default/fs_default.sc"):string()),
        filename                = "fs_%s.sc",
    }
}

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

local PROPERTY_CREATORS<const> = {
    uniform = function (n, v, num)
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
    sampler = function (n, v, num)
        --EX: mediump SAMPLER2D(name, stage)
        return ("%s %s(%s, %d);"):format(
            v.precision or "mediump",
            v.sampler or "SAMPLER2D",
            n, v.stage)
    end,
    buffer = function (n, v, num)
        -- access stage type(default vec4)
        return ("%s(%s, %s, %d);"):format(ACCESS_NAMES[assert(v.access)], n, assert(v.elemtype), assert(v.stage))
    end,
}

local function generate_properties(stage, properties)
    local content = {}
    for name, v in pairs(properties) do
        local st, num = which_property_type(name, v)
        if ((st == "sampler" or st == "buffer") and stage == "fs") or st == "uniform" then
            content[#content+1] = assert(PROPERTY_CREATORS[st])(name, v, num)
        end
    end
    for k,v in pairs(DEF_PBR_UNIFORM) do
        if not properties[k] then
            content[#content+1] = v.shader
        end
    end
    return table.concat(content, "\n")
end

local function parse_varyings_input(varyings)
    local t = {}
    for k, v in pairs(varyings) do
        if type(v) == "string" then
            local dd = {}
            for e in v:gmatch "%w+" do
                dd[#dd+1] = e
            end
            t[k] = {
                type = dd[1],
                bind = dd[2],
            }
        else
            assert(v.bind)
            assert(v.type)
            t[k] = v
        end
    end

    return t
end

local function vfs_exists(vfs, path)
    return vfs.type(path) ~= nil
end

local function read_varyings_input(setting, inputfolder, fx)
    local varyings = assert(fx.varyings, "Need varyings defined")
    if type(varyings) == "string" then
        if varyings:sub(1, 1) == "/" then
            if vfs_exists(setting.vfs, varyings) then
                varyings = setting.vfs.realpath(varyings)
            else
                error(("Invalid varyings path:%s"):format(varyings))
            end
        else
            local p = inputfolder / varyings
            if lfs.exists(p) then
                varyings = p:string()
            else
                error(("Invalid varyings path:%s, not in resource folder:%s"):format(varyings, inputfolder:string()))
            end
        end
        varyings = datalist.parse(lfastio.readall_s(varyings))
    else
        assert(type(varyings) == "table")
    end

    return parse_varyings_input(varyings)
end

local function write_file(filename, c)
    local f<close> = io.open(filename:string(), "wb") or error(("Failed to open filename:%s"):format(filename))
    f:write(c)
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

local function is_input_varying(n, v)
    local nt = n:sub(1, 1)
    if v.input then
        if nt == "v" then
            log.warn(("%s defined as input vs varying, but use 'a_' prefix, try to use 'v_' prefix"):format(n))
        end
    end

    return nt == 'a'
end

local function is_output_varying(n, v)
    local nt = n:sub(1, 1)
    if v.output then
        if nt == "a" then
            log.warn(("%s defined as input vs varying, but use 'a_' prefix, try to use 'v_' prefix"):format(n))
        end
    end

    return nt == 'v'
end

local SEMANTICS_INFOS<const> = {
	a_position	= {
		bind = "POSITION",
        macro = "WITH_POSITION_ATTRIB=1",
	},
    a_color0	= {
		bind = "COLOR0",
        macro = "WITH_COLOR0_ATTRIB=1",
	},
    a_color1	= {
		bind = "COLOR1",
        macro = "WITH_COLOR1_ATTRIB=1",
	},
	a_normal	= {
		bind = "NORMAL",
        macro = "WITH_NORMAL_ATTRIB=1",
	},
	a_tangent	= {
		bind = "TANGENT",
        macro = "WITH_TANGENT_ATTRIB=1",
	},
    a_bitanget	= {
		bind = "BITANGENT",
        macro = "WITH_BITANGENT_ATTRIB=1",
	},
    a_indices	= {
		bind = "INDICES",
        macro = "WITH_INDICES_ATTRIB=1",
	},
    a_weight	= {
		bind = "WEIGHT",
        macro = "WITH_WEIGHT_ATTRIB=1",
	},
	a_texcoord0	= {
		bind = "TEXCOORD0",
        macro = "WITH_TEXCOORD0_ATTRIB=1",
	},
	a_texcoord1	= {
		bind = "TEXCOORD1",
        macro = "WITH_TEXCOORD1_ATTRIB=1",
	},
	a_texcoord2	= {
		bind = "TEXCOORD2",
        macro = "WITH_TEXCOORD2_ATTRIB=1",
	},
	a_texcoord3	= {
		bind = "TEXCOORD3",
        macro = "WITH_TEXCOORD3_ATTRIB=1",
	},
	a_texcoord4	= {
		bind = "TEXCOORD4",
        macro = "WITH_TEXCOORD4_ATTRIB=1",
	},
	a_texcoord5	= {
		bind = "TEXCOORD5",
        macro = "WITH_TEXCOORD5_ATTRIB=1",
	},
	a_texcoord6	= {
		bind = "TEXCOORD6",
        macro = "WITH_TEXCOORD6_ATTRIB=1",
	},
    a_texcoord7	= {
		bind = "TEXCOORD7",
        macro = "WITH_TEXCOORD7_ATTRIB=1",
	},
    i_data0	= {
		bind = "TEXCOORD7",
        macro = "WITH_INSTANCE_DATA0_ATTRIB=1",
	},
    i_data1	= {
		bind = "TEXCOORD6",
        macro = "WITH_INSTANCE_DATA1_ATTRIB=1",
	},
    i_data2	= {
		bind = "TEXCOORD5",
        macro = "WITH_INSTANCE_DATA2_ATTRIB=1",
	},
    i_data3	= {
		bind = "TEXCOORD4",
        macro = "WITH_INSTANCE_DATA3_ATTRIB=1",
	},
    i_data4	= {
		bind = "TEXCOORD3",
        macro = "WITH_INSTANCE_DATA4_ATTRIB=1",
	},
}

local function gen_append_code(d, tabnum)
    tabnum = tabnum or 1
    local tab
    if tabnum > 0 then
        tab = ('\t'):rep(tabnum)
    end

    if tab then
        return function (c)
            d[#d+1] = tab .. c
        end
    else
        return function (c)
            d[#d+1] = c
        end
    end
end

local function build_input_var(varyingcontent)
    local varying_def_decls = {}
    local input_decls, varying_decls = {}, {}
    local input_assignments, varying_assignments = {}, {}

    local vdd_ac0 = gen_append_code(varying_def_decls, 0)

    local ia_ac1 = gen_append_code(input_assignments, 1)
    local va_ac1 = gen_append_code(varying_assignments, 1)

    local inputs, varyings = {}, {}
    local iac0, iac1 = gen_append_code(inputs, 0), gen_append_code(inputs, 1)
    local vac0, vac1 = gen_append_code(varyings, 0), gen_append_code(varyings, 1)
    
    iac0 "struct VSInput {"
    vac0 "struct Varyings {"

    local shaderfmt = "\t%s %s;"
    for k, v in sortpairs(varyingcontent) do
        vdd_ac0(("%s %s : %s;\n"):format(v.type, k, v.bind or SEMANTICS_INFOS[k].bind))

        if is_input_varying(k, v) then
            iac1(shaderfmt:format(v.type, k))
            ia_ac1(("vsinput.%s = %s;"):format(k, k))

            input_decls[#input_decls+1] = k
        else
            assert(is_output_varying(k, v))
            vac1(shaderfmt:format(v.type, k))
            va_ac1(("%s = vsoutput.%s;"):format(k, k))

            varying_decls[#varying_decls+1] = k
        end
    end

    iac0 "};"
    vac1 "};"
    
    return {
        varying_def         = varying_def_decls,
        inputs              = inputs,
        varyings            = varyings,
        input_decls         = input_decls,
        varying_decls       = varying_decls,
        input_assignments   = input_assignments,
        varying_assignments = varying_assignments,
    }
end

local function build_fx_content(mat, varyings, results)
    local fx, properties, state = mat.fx, mat.properties, mat.state

    local inputdecl         = table.concat(results.input_decls, " ")
    local varyingdecl       = table.concat(results.varying_decls, " ")
    local inputassignment   = table.concat(results.input_assignments, "\n")
    local varyingassignment = table.concat(results.varying_assignments, "\n")

    local fsinput_assignments = {}
    for _, v in ipairs(results.varying_assignments) do
        local lhs, rhs = v:match "([%w_]+)%s*=%s*varyings%.([%w_]+)"
        assert(lhs and rhs and lhs == rhs)
        fsinput_assignments[#fsinput_assignments+1] = ("varyings.%s = %s;"):format(rhs, lhs)
    end

    fsinput_assignments[#fsinput_assignments+1] = "varyings.frag_coord = gl_FragCoord;"
    local isdoublesize = state.CULL == "NONE"
    if isdoublesize then
        fsinput_assignments[#fsinput_assignments+1] = "varyings.is_frontfacing = gl_FrontFacing;"
    end

    local function build_vs_code()
        local d = {}
        local ac0 = gen_append_code(d, 0)
        local ac1 = gen_append_code(d, 1)
        ac0 [[
#include "common/transform.sh"
vec4 CUSTOM_VS_POSITION(VSInput vsinput, out Varyings varyings, out mat4 worldmat){
    worldmat = get_world_matrix(vsinput.a_indices, vsinput.a_weight);
    vec4 posCS;
	varyings.v_posWS = transform_worldpos(worldmat, vsinput.a_position, posCS);
    return posCS;
}
]]

        ac0 "void CUSTOM_VS(mat4 worldmat, VSInput vsinput, out Varyings varyings) {"

        --v_posWS
        local assign_fmt = "varyings.%s = vsinput.%s;"
        --a_texcoord[0-7]
        for i=0, 7 do
            local a_texcoord = "a_texcoord" .. i
            if varyings[a_texcoord] then
                ac1(assign_fmt:format("v_texcoord" .. i, a_texcoord))
            end
        end

        --a_color0
        if varyings.a_color0 then
            ac1(assign_fmt:format("v_color0", "a_color0"))
        end

        --normal/tangent/bitangent
        if varyings.a_tangent or varyings.a_normal or varyings.a_bitangent then
            if (varyings.a_tangent or varyings.a_bitangent) and not varyings.a_texcoord0 then
                error "shader need tbn, but 'a_texcoord0' is not provided"
            end

            ac1 "mat3 wm3 = (mat3)worldmat;"
            if varyings.a_tangent and varyings.a_tangent.pack_from_quat then
                if varyings.a_normal then
                    error "tangent is pack from quaternion, 'a_normal' should not define"
                end

                if varyings.a_tangent.type ~= "vec4" then
                    error "'a_tangent' pack from quaternion, need vec4 type"
                end

                
                ac1 "const mediump vec4 quat = vsinput.a_tangent;"
                ac1 "mediump vec3 normal 	= quat_to_normal(quat);"
                ac1 "mediump vec3 tangent 	= quat_to_tangent(quat);"
                ac1 "varyings.v_normal		= mul(wm3, normal);"
                ac1 "varyings.v_tangent	    = mul(wm3, tangent);"
                ac1 "varyings.v_bitangent	= cross(varyings.v_normal, varyings.v_tangent);"
    
            else
                if varyings.a_normal then
                    assert(varyings.v_normal, "No 'v_normal' defined")
                    ac1 "varyings.v_normal		= mul(wm3, vsinput.a_normal);"
                end

                if varyings.v_tangent then
                    assert(varyings.a_normal)
                    assert(varyings.v_tangent, "No 'v_tangent' defined")
                    assert(varyings.v_bitangent, "'v_tangent' already defined, it need 'v_bitangent' defined the meantime")

                    ac1 "varyings.v_tangent		= mul(wm3, vsinput.a_tangent);"
                    if varyings.a_bitangent then
                        ac1 "varyings.v_bitangent	= mul(wm3, vsinput.a_bitangent);"
                    else
                        ac1 "varyings.v_bitangent	= cross(varyings.v_normal, varyings.v_tangent);"
                    end
                end
            end
        end
        ac0 "}"
        return d
    end

    local function build_fs_code()
        local d = {}
        local ac0 = gen_append_code(d, 0)
        local ac1 = gen_append_code(d, 1)
        ac0 [[
void CUSTOM_FS(in Varyings varyings, inout FSOutput fsoutput) {
    material_info mi = (material_info)0;
]]

        if varyings.v_texcoord0 then
            ac1 "mi.uv0 = uv_motion(varyings.v_texcoord0);";
        end

        ac1 "mi.V = normalize(u_eyepos.xyz - varyings.pos.xyz);"
        ac1 "mi.screen_uv = calc_normalize_fragcoord(varyings.frag_coord.xy);"

        if fx.setting.USING_LIGHTMAP then
            ac1 "mi.lightmap_uv  = varyings.v_texcoord1;"
        end

        ac0 "\n"

        assert(properties.u_pbr_factor)

        if varyings.v_posWS then
            ac1 "mi.posWS        = varyings.pos.xyz;"
            ac1 "mi.distanceVS   = varyings.pos.w;"
        end
        ac0 "\n"

        --basecolor
        assert(properties.u_basecolor_factor)
        if varyings.v_color0 then
            ac1 "mi.basecolor = varyings.v_color0;"
        else
            ac1 "mi.basecolor = vec4_splat(1.0);"
        end
        ac1 "mi.basecolor *= u_basecolor_factor;"
        if varyings.v_texcoord0 and properties.s_basecolor then
            ac1 "mi.basecolor *= texture2D(s_basecolor, texcoord);"
        end
        if fx.setting.ALPHAMODE_OPAQUE then
            ac1 "mi.basecolor.a = u_alpha_mask_cutoff;"
        end
        ac0 "\n"

        --emissive
        assert(properties.u_emissive_factor)
        ac1 "mi.emissivecolor = u_emissive_factor;"
        if varyings.v_texcoord0 and properties.s_emissive then
            ac1 "mi.emissivecolor *= texture2D(s_emissive, texcoord);"
        end
        ac0 "\n"
        
        --roughness&matellic
        ac1 "mi.metallic = u_metallic_factor;"
        ac1 "mi.perceptual_roughness = u_roughness_factor;"
        if varyings.v_texcoord0 and properties.s_metallic_roughness then
            ac1 "//Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel."
            ac1 "//This layout intentionally reserves the 'r' channel for (optional) occlusion map data"
            ac1 "vec4 mrSample = texture2D(s_metallic_roughness, varyings.v_texcoord0);"
            ac1 "mi.perceptual_roughness *= mrSample.g;"
            ac1 "mi.metallic *= mrSample.b;"
        end

        ac1 "mi.perceptual_roughness  = clamp(mi.perceptual_roughness, 1e-6, 1.0);"
        ac1 "mi.metallic              = clamp(mi.metallic, 1e-6, 1.0);"

        ac0 "\n"
        --occlusion
        ac1 "mi.occlusion = u_occlusion_strength"
        if varyings.v_texcoord0 and properties.s_occlusion then
            ac1 "mi.occlusion *= texture2D(s_occlusion,  varyings.v_texcoord0).r;"
        end

        --normal
        if varyings.v_normal then
            ac1 "mi.gN = normalize(varyings.v_normal);"
            if properties.s_normal and varyings.v_texcoord0 then
                if varyings.v_tangent and varyings.v_bitangent then
                    ac1 "mi.T = normalize(varyings.v_tangent);"
                    ac1 "mi.B = normalize(varyings.v_bitangent);"
                    ac1 "mat3 tbn = mat3(mi.T, mi.B, mi.gN);"
                else
                    ac1 "mat3 tbn = cotangent_frame(mi.gN, varyings.v_posWS, varyings.v_texcoord0);"
                    ac1 "mi.T = tbn[0];"
                    ac1 "mi.B = tbb[1];"
                end
                ac0 "\n"
                ac1 "mediump vec3 normalTS = fetch_normal_from_tex(s_normal, varyings.v_texcoord0);"
                ac1 "mi.N = normalize(mul(normalTS, tbn));// same as: mul(transpose(tbn), normalTS)"
            end

            if isdoublesize then
                if varyings.v_tangent then
                    ac1 "mi.T = -mi.T;"
                    ac1 "mi.B = -mi.B;"
                end
                ac1 "mi.N  = -mi.N;"
                ac1 "mi.gN = -mi.gN;"
            end
        end

        --bend normal
        if fx.ENABLE_BENT_NORMAL then
            ac1 "const vec3 bent_normalTS = vec3(0.0, 1.0, 0.0); //TODO: need bent_normal should come from ssao or other place"
            ac1 "mi.bent_normal = bent_normalTS;"
        end
        ac0 "}\n"
        return d
    end

    local function build_vsinputoutput()
        local input = table.concat(results.inputs, "\n")
        local varying = table.concat(results.varyings, "\n")

        return ("%s\n\n%s"):format(input, varying)
    end

    local function build_fsinputoutput()
        local fsoutput = {}
        for i=1, #results.varyings-1 do
            fsoutput[i] = results.varyings[i]
        end

        assert(results.varyings[#results.varyings] == "};")

        fsoutput[#fsoutput+1] = "\tvec4 frag_coord;"
        fsoutput[#fsoutput+1] = "\tbool is_frontfacing;"

        fsoutput[#fsoutput+1] = [[};
struct FSOutput{
    vec4 color;
};
]]
        return table.concat(fsoutput, "\n")
    end

    return {
        vs = {
            ["@VSINPUT_VARYING_DEFINE"] = ("$input %s\n$output %s\n"):format(inputdecl, varyingdecl),
            ["@VSINPUTOUTPUT_STRUCT"]   = build_vsinputoutput(),
            ["@VS_PROPERTY_DEFINE"]     = generate_properties("vs", properties),
            ["@VS_FUNC_DEFINE"]         = fx.vs_code or build_vs_code(),
            ["@VSINPUT_INIT"]           = inputassignment,
            ["@OUTPUT_VARYINGS"]        = varyingassignment,
        },
        fs = {
            ["@FSINPUT_VARYINGS_DEFINE"]= "$input " .. varyingdecl,
            ["@FSINPUTOUTPUT_STRUCT"]   = build_fsinputoutput(),
            ["@FS_PROPERTY_DEFINE"]     = generate_properties("fs", properties),
            ["@FS_FUNC_DEFINE"]         = fx.fs_code or build_fs_code(),
            ["@FSINPUT_FROM_VARYING"]   = table.concat(fsinput_assignments, "\n"),
        }
    }
end

local function write_varying_def_sc(output, varying_def)
    local varying_path = output / "varying.def.sc"
    write_file(varying_path, table.concat(varying_def, ""))
    return varying_path:string()
end

local function build_fx_macros(mat, varyings)
    local m = {}
    for k in pairs(varyings) do
        local v = SEMANTICS_INFOS[k]
        if v then
            m[#m+1] = v.macro
        end
    end

    if varyings.a_tangent.pack_from_quat then
        m[#m+1] = "TANGENT_PACK_FROM_QUAT=1"
    end

    local state = mat.state
    if state.CULL == "NONE" then
        m[#m+1] = "WITH_DOUBLE_SIDE=1"
    end

    local properties = mat.properties
    if properties.s_basecolor then
        m[#m+1] = "HAS_BASECOLOR_TEXTURE=1"
    end

    if properties.s_normal then
        m[#m+1] = "HAS_NORMAL_TEXTURE=1"
    end

    if properties.s_metallic_roughness then
        m[#m+1] = "HAS_METALLIC_ROUGHNESS_TEXTURE=1"
    end

    if properties.s_emissive then
        m[#m+1] = "HAS_EMISSIVE_TEXTURE=1"
    end

    if properties.s_occlusion then
        m[#m+1] = "HAS_OCCLUSION_TEXTURE=1"
    end

    return m
end

local function gen_fx(setting, input, output, mat)
    local fx = mat.fx
    local varyings = read_varyings_input(setting, input, fx)
    local results = build_input_var(varyings)

    fx.varying_path = write_varying_def_sc(output, results.varying_def)

    return build_fx_content(mat, varyings, results), build_fx_macros(mat, varyings)
end

local function gen_shader(setting, fx, stage, shaderdefined)
    local si = assert(DEF_SHADER_INFO[stage])
    local shader = si.template:gsub("@[%w_]+", shaderdefined[stage])

    local fn = si.filename:format(sha1(shader))
    local filename = setting.scpath / fn

    if not lfs.exists(filename) then
        write_file(filename, shader)
    end
    if fx[stage] then
        error "vs/fs should not define when use genertaed shader"
    end
    fx[stage] = fn
    return filename
end

return {
    gen_fx              = gen_fx,
    gen_shader          = gen_shader,
    DEF_PBR_UNIFORM     = DEF_PBR_UNIFORM,
    LOCAL_SHADER_BASE   = LOCAL_SHADER_BASE
}