local sha1     = require "sha1"
local lfs      = require "bee.filesystem"
local datalist = require "datalist"
local fastio   = require "fastio"
local L        = import_package "ant.render.core".layout

local settings      = import_package "ant.settings"
local ENABLE_SHADOW<const>      = settings:get "graphic/shadow/enable"

local FILTER_MODE_MACROS<const> = {
    pcf  = "SM_PCF=1",
    evsm = "SM_EVSM=1",
    hard = "SM_HARD=1",
}

local FILTER_MODE<const> = settings:get "graphic/shadow/filter_mode" or "hard"
local SHADOW_FILTER_MACROS = setmetatable({}, {__index=function(t, fm)
    local r
    if fm == "pcf" then
        local PCF = settings:get "graphic/shadow/pcf"
        local _ = PCF or error "Invalid setting for filter mode:pcf, need define 'graphic/shadow/pcf'"

        local PCF_TYPE_DEFINES<const> = {
            fast = 1,
            fix4 = 2,
            simple = 3,
        }

        local PCF_TYPE<const>           = assert(PCF.type, "'pcf' needed 'type'")
        local PCF_FILTER_SIZE<const>    = assert(PCF.size, "'pcf' needed 'size'")

        r = {}
        r[#r+1] = "PCF_TYPE=" .. PCF_TYPE_DEFINES[PCF_TYPE]
        r[#r+1] = "PCF_FILTER_SIZE=" .. assert(PCF_FILTER_SIZE)
        if PCF_TYPE == "fast" then
            local PCF_FILTER_TYPES<const> = {
                disc            = 1,
                triangle        = 2,
                halfmoon        = 3,
                uniform         = 4,
                gaussian_like   = 5,
            }
            r[#r+1] = "PCF_FILTER_TYPE=" .. PCF_FILTER_TYPES[PCF.filter or "uniform"]
        end
    end

    if fm == "evsm" then
        r = {}
        local evsm = settings:get "graphic/shadow/evsm"
        local format_count = {
            RGBA16F = 4,
            RGBA32F = 4,
            RG16F   = 2,
            RG32F   = 2,
        }
        
        local c = format_count[evsm.format] or error(("Invalid format:%s"):format(evsm.format))
        local sampleradius = evsm.sample_radius
        if sampleradius ~= 1 and sampleradius ~= 2 and sampleradius ~= 3 then
            error(("evsm sample radius should only be [1/2/3], %f defined"):format(sampleradius))
        end

        r[#r+1] = "EVSM_COMPONENT=" .. c
        r[#r+1] = "EVSM_SAMPLE_RADIUS=" ..evsm.sample_radius

        local filter_types<const> = {
            uniform = 1,
            gaussian = 2,
        }
        r[#r+1] = "EVSM_FILTER_TYPE=" .. (filter_types[evsm.filter_type] or error(("Invalid filter type for evsm: %s, only [uniform/gaussian] is valid"):format(evsm.filter_type or "")))
    end

    if fm == "hard" then
        r = {}
    end

    if nil == r then
        error(("Not support filter_mode: %s"):format(FILTER_MODE))
    end

    t[fm] = r
    return r
end})

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
        template                = fastio.readall_s((LOCAL_SHADER_BASE / "default/vs_default.sc"):string()),
        filename                = "vs_%s.sc",
    },
    di = {
        defines = {
            VARYING_DEFINE      = "@VSINPUT_VARYING_DEFINE",
            INPUTOUTPUT_STRUCT  = "@VSINPUTOUTPUT_STRUCT",
    
            PROPERTY_DEFINE     = "@VS_PROPERTY_DEFINE",
            FUNC_DEFINE         = "@VS_FUNC_DEFINE",
    
            INPUT_INIT          = "@VSINPUT_INIT",
            OUTPUT_VARYINGS     = "@OUTPUT_VARYINGS",
        },
        template                = fastio.readall_s((LOCAL_SHADER_BASE / "default/vs_default.sc"):string()),
        filename                = "di_%s.sc",
    },
    fs = {
        defines = {
            VARYING_DEFINE      = "@FSINPUT_VARYINGS_DEFINE",
            INPUTOUTPUT_STRUCT  = "@FSINPUTOUTPUT_STRUCT",
    
            PROPERTY_DEFINE     = "@FS_PROPERTY_DEFINE",
            FUNC_DEFINE         = "@FS_FUNC_DEFINE",
    
            INPUT_INIT          = "@FSINPUT_INIT",
        },
        template                = fastio.readall_s((LOCAL_SHADER_BASE / "default/fs_default.sc"):string()),
        filename                = "fs_%s.sc",
    }
}

local DEF_PBR_UNIFORM <const> = {
    u_basecolor_factor = {
        attrib = {1, 1, 1, 1},
    },
    u_emissive_factor  = {
        attrib = {0, 0, 0, 0},
    },
    u_pbr_factor       ={
        attrib = {0, 1, 0, 1} --metalic, roughness, alpha mask, occlusion
    }
}

local ACCESS_NAMES<const> = {
    r = "BUFFER_RO",
    w = "BUFFER_WO",
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

local function generate_properties(mat)
    local properties = mat.properties or {}
    mat.properties = properties

    local content = {
        common = {}, vs = {}, fs = {}
    }

    local function add_property(n, attrib)
        if not properties[n] then
            properties[n] = attrib
        end
    end

    for k,v in pairs(DEF_PBR_UNIFORM) do
        add_property(k, v.attrib)
    end

    if mat.fx.setting.uv_motion then
        add_property("u_uvmotion", {0, 0, 0, 0})
    end

    for name, v in pairs(properties) do
        local st, num = which_property_type(name, v)
        if st == "uniform" then
            content.common[#content.common+1] = assert(PROPERTY_CREATORS[st])(name, v, num)
        end

        if st == "sampler" or st == "buffer" then
            content.fs[#content.fs+1] = assert(PROPERTY_CREATORS[st])(name, v, num)
        end
    end

    local cc = table.concat(content.common, "\n")
    local fmt = "%s\n%s"
    return fmt:format(cc, table.concat(content.vs, "\n")), fmt:format(cc, table.concat(content.fs, "\n"))
end

local function vfs_exists(vfs, path)
    return vfs.type(path) ~= nil
end

local function read_varyings_input(setting, inputfolder, fx)
    local varyings = fx.varyings
    if varyings == nil then
        return
    end
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
        varyings = datalist.parse(fastio.readall_f(varyings))
    else
        assert(type(varyings) == "table")
    end

    return L.parse_varyings(varyings)
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
        if nt == 'v' then
            log.warn(("%s defined as input vs varying, but use 'a_' prefix, try to use 'v_' prefix"):format(n))
        end
    end

    return nt == 'a' or nt == 'i'
end

local function is_output_varying(n, v)
    local nt = n:sub(1, 1)
    if v.output then
        if nt == 'a' or nt == 'i' then
            log.warn(("%s defined as input vs varying, but use 'a_' prefix, try to use 'v_' prefix"):format(n))
        end
    end

    return nt == 'v'
end

local function code_gen(d, tab0, tab1, tab2)
    local function code_gen_(tabnum)
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

    local g0, g1, g2
    if tab0 then
        g0 = code_gen_(tab0)
    end
    if tab1 then
        g1 = code_gen_(tab1)
    end
    if tab2 then
        g2 = code_gen_(tab2)
    end
    return g0, g1, g2
end

local function build_input_var(varyingcontent)
    local varying_def_decls = {}
    local di_varying_def_decls = {}
    local input_decls, di_input_decls, varying_decls = {}, {}, {}
    local input_assignments, di_input_assignments, varying_assignments = {}, {}, {}

    local vdd_ac0 = code_gen(varying_def_decls, 0)
    local dvdd_ac0 = code_gen(di_varying_def_decls, 0)

    local ia_ac1 = code_gen(input_assignments, 1)
    local dia_ac1 = code_gen(di_input_assignments, 1)
    local va_ac1 = code_gen(varying_assignments, 1)

    local inputs, di_inputs, varyings = {}, {}, {}
    local iac0, iac1 = code_gen(inputs, 0, 1)
    local diac0, diac1 = code_gen(di_inputs, 0, 1)
    local vac0, vac1 = code_gen(varyings, 0, 1)
    
    iac0 "struct VSInput {"
    diac0 "struct VSInput {"
    vac0 "struct Varyings {"

    local shaderfmt = "%s %s;"
    for k, v in sortpairs(varyingcontent) do
        vdd_ac0(("%s %s : %s;"):format(v.type, k, v.bind or L.SEMANTICS_INFOS[k].bind))
        dvdd_ac0(("%s %s : %s;"):format(v.type, k, v.bind or L.SEMANTICS_INFOS[k].bind))

        local member_name = k:match "[avi]_(%w+)"
        if is_input_varying(k, v) then
            iac1(shaderfmt:format(v.type, member_name))
            diac1(shaderfmt:format(v.type, member_name))
            ia_ac1(("vsinput.%s = %s;"):format(member_name, k))
            dia_ac1(("vsinput.%s = %s;"):format(member_name, k))

            input_decls[#input_decls+1] = k
            di_input_decls[#di_input_decls+1] = k
        else
            assert(is_output_varying(k, v))
            vac1(shaderfmt:format(v.type, member_name))
            va_ac1(("%s = varyings.%s;"):format(k, member_name))

            varying_decls[#varying_decls+1] = k
        end
    end

    if not varyingcontent.i_data0 then
        dvdd_ac0(("%s %s : %s;"):format("vec4", "i_data0", "TEXCOORD7"))
        dia_ac1(("vsinput.%s = %s;"):format("data0", "i_data0"))
        di_input_decls[#di_input_decls+1] = "i_data0"
        diac1(shaderfmt:format("vec4", "data0"))
    end

    if not varyingcontent.i_data1 then
        dvdd_ac0(("%s %s : %s;"):format("vec4", "i_data1", "TEXCOORD6"))
        dia_ac1(("vsinput.%s = %s;"):format("data1", "i_data1"))
        di_input_decls[#di_input_decls+1] = "i_data1"
        diac1(shaderfmt:format("vec4", "data1"))
    end

    if not varyingcontent.i_data2 then
        dvdd_ac0(("%s %s : %s;"):format("vec4", "i_data2", "TEXCOORD5"))
        dia_ac1(("vsinput.%s = %s;"):format("data2", "i_data2"))
        di_input_decls[#di_input_decls+1] = "i_data2"
        diac1(shaderfmt:format("vec4", "data2"))
    end

    if not varyingcontent["v_posWS"] then
        vac1 "vec3 posWS;"
    end

    iac0 "};"
    diac0 "};"
    vac0 "};"
    
    return {
        varying_def             = varying_def_decls,
        di_varying_def          = di_varying_def_decls,
        inputs                  = inputs,
        di_inputs               = di_inputs,
        varyings                = varyings,
        input_decls             = input_decls,
        di_input_decls          = di_input_decls,
        varying_decls           = varying_decls,
        input_assignments       = input_assignments,
        di_input_assignments    = di_input_assignments,
        varying_assignments     = varying_assignments,
    }
end

local function readfile(f)
    local ff<close> = io.open(f:string())
    if ff then
        return ff:read "a"
    end
end

local INCLUDE_FILE_CACHES = {}

local function search_file_content(searchpaths, filename)
    for _, p in ipairs(searchpaths) do
        local fullfile = p / filename
        local sfullfile = fullfile:string()
        local c = INCLUDE_FILE_CACHES[sfullfile]
        if c then
            return c
        end

        c = readfile(fullfile)
        if c then
            INCLUDE_FILE_CACHES[sfullfile] = c
            return c
        end
    end
    
end
local function check_func_defined(inputfolder, code, funcname)
    if code then
        if code:match(funcname) then
            return true
        end

        local searchpaths = {inputfolder, LOCAL_SHADER_BASE}
        --NOTE: we only search one depth
        for fn in code:gmatch "#include [\"]([^\"]+)\"" do
            local c = search_file_content(searchpaths, fn)
            if c and c:match(funcname) then
                return true
            end
        end
    end
    
end

local function build_custom_vs_worldmat_func(d, inputfolder, mat, varyings, isdi)
    if check_func_defined(inputfolder, mat.fx.vs_code, "LOAD_WORLDMAT") then
        return
    end

    local ac0, ac1 = code_gen(d, 0, 1)

    ac0 "//code gen by genshader.lua"
    ac0 "mat4 LOAD_WORLDMAT(VSInput vsinput){"
    local isskinning = (varyings.a_indices and varyings.a_weight) and (not mat.fx.setting.no_skinning)

    --TODO: gpu skinning with draw indirect is not support right
    if isskinning then
        ac1 "return calc_bone_transform(vsinput.indices, vsinput.weight);"
    elseif isdi then
        ac1 "mat4 hitchmat = mat4(vsinput.data0, vsinput.data1, vsinput.data2, vec4(0.0, 0.0, 0.0, 1.0));"
        ac1 "return mul(hitchmat, u_model[0]);"
    else
        ac1 "return u_model[0];"
    end

    ac0 "}"
end

local function build_custom_vs_position_func(d, inputfolder, mat)
    if check_func_defined(inputfolder, mat.fx.vs_code, "CUSTOM_VS_POSITION") then
        return
    end
    local ac0, ac1 = code_gen(d, 0, 1)
    ac0 "//code gen by genshader.lua"
    ac0 "vec4 CUSTOM_VS_POSITION(VSInput vsinput, inout Varyings varyings, mat4 worldmat){"
    ac1     "vec4 posCS;"
    ac1     "varyings.posWS = transform_worldpos(worldmat, vsinput.position, posCS);"
    ac1     "return posCS;"
    ac0 "}"
end

local function build_custom_vs_func(d, inputfolder, mat, varyings)
    if check_func_defined(inputfolder, mat.fx.vs_code, "CUSTOM_VS") then
        return
    end
    local ac0, ac1 = code_gen(d, 0, 1)
    ac0 "//code gen by genshader.lua"
    ac0 "void CUSTOM_VS(mat4 worldmat, VSInput vsinput, inout Varyings varyings) {"

    local assign_fmt = "varyings.%s = vsinput.%s;"
    --a_texcoord[0-7]
    for i=0, 7 do
        if varyings["a_texcoord" .. i] and varyings["v_texcoord" .. i] then
            local texcoord = "texcoord" .. i
            ac1(assign_fmt:format(texcoord, texcoord))
        end
    end

    --a_color[0-3]
    for i=0, 3 do
        if varyings["a_color"..i] and varyings["v_color".. i] then
            local color = "color" .. i
            ac1(assign_fmt:format(color, color))
        end
    end

    --normal/tangent/bitangent
    if mat.fx.setting.lighting == "on" then
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

                ac1 "const vec4 quat        = vsinput.tangent;"
                ac1 "const vec3 normal      = quat_to_normal(quat);"
                ac1 "const vec3 tangent     = quat_to_tangent(quat);"
                ac1 "varyings.normal        = mul(wm3, normal);"
                ac1 "varyings.tangent       = mul(wm3, tangent);"
                ac1 "varyings.bitangent     = cross(varyings.normal, varyings.tangent) * sign(quat.w);"

            else
                if varyings.a_normal then
                    assert(varyings.v_normal, "No 'v_normal' defined")
                    ac1 "varyings.normal  = mul(wm3, vsinput.normal);"
                end

                if varyings.a_tangent then
                    assert(varyings.a_tangent.type == "vec3" or varyings.a_tangent.type == "vec4")

                    assert(varyings.a_normal)
                    assert(varyings.v_tangent, "No 'v_tangent' defined")
                    assert(varyings.v_tangent.type == "vec3", "v_tangent type should only be 'vec3'")

                    assert(varyings.v_bitangent, "'v_tangent' already defined, it need 'v_bitangent' defined the meantime")
                    assert(varyings.v_bitangent.type == "vec3", "v_bitangent should only be 'vec3'")

                    ac1 "varyings.tangent = mul(wm3, vsinput.tangent.xyz);"

                    if varyings.a_bitangent then
                        assert(varyings.a_bitangent.type == "vec3")
                        ac1 "varyings.bitangent = mul(wm3, vsinput.bitangent);"
                    else
                        if varyings.a_bitangent.type == "vec3" then
                            ac1 "varyings.bitangent = cross(varyings.normal, varyings.tangent);"
                        else
                            ac1 "varyings.bitangent = cross(varyings.normal, varyings.tangent) * sign(vsinput.tangent.w);"
                        end
                    end
                end
            end
        end
    end
    ac0 "}"
end

local function build_vs_code(inputfolder, mat, varyings, isdi)
    local d = {}
    build_custom_vs_worldmat_func(d, inputfolder, mat, varyings, isdi)
    build_custom_vs_position_func(d, inputfolder, mat)
    build_custom_vs_func(d, inputfolder, mat, varyings)

    if mat.fx.vs_code then
        d[#d+1] = mat.fx.vs_code
    end
    return table.concat(d, "\n")
end

local function build_fs_code(inputfolder, mat, varyings)
    local fx = mat.fx
    if check_func_defined(inputfolder, fx.fs_code, "CUSTOM_FS") then
        return fx.fs_code
    end
    local properties, state = mat.properties, mat.state

    local d = {}
    local ac0, ac1, ac2 = code_gen(d, 0, 1, 2)
    ac0 "//code gen by genshader.lua"
    ac0 "void CUSTOM_FS(Varyings varyings, inout FSOutput fsoutput) {"
    ac1  "material_info mi = (material_info)0;"

    --basecolor
    assert(properties.u_basecolor_factor)
    if varyings.v_color0 then
        ac1 "mi.basecolor = varyings.color0;"
    else
        ac1 "mi.basecolor = vec4_splat(1.0);"
    end
    ac1 "mi.basecolor *= u_basecolor_factor;"
    if varyings.v_texcoord0 and properties.s_basecolor then
        ac1 "mi.basecolor *= texture2D(s_basecolor, varyings.texcoord0);"
    end
    if fx.setting.ALPHAMODE_OPAQUE then
        ac1 "mi.basecolor.a = u_alpha_mask_cutoff;"
    end

    --emissive
    assert(properties.u_emissive_factor)
    ac1 "mi.emissive = u_emissive_factor;"
    if varyings.v_texcoord0 and properties.s_emissive then
        ac1 "mi.emissive *= texture2D(s_emissive, varyings.texcoord0);"
    end

    if fx.setting.USING_LIGHTMAP then
        ac1 "mi.lightmap_uv  = varyings.texcoord1;"
    end

    if fx.setting.lighting == "on" then
        ac1 "mi.V = normalize(u_eyepos.xyz - varyings.posWS.xyz);"
        ac1 "mi.screen_uv = calc_normalize_fragcoord(varyings.frag_coord.xy);"
        ac1 "mi.frag_coord = varyings.frag_coord;"

        assert(properties.u_pbr_factor)

        if varyings.v_posWS then
            ac1 "mi.posWS        = varyings.posWS;"
            ac1 "mi.distanceVS   = varyings.frag_coord.w;"
        end
        ac0 "\n"
        
        --roughness&matellic
        ac1 "mi.metallic = u_metallic_factor;"
        ac1 "mi.perceptual_roughness = u_roughness_factor;"
        if varyings.v_texcoord0 and properties.s_metallic_roughness then
            ac1 "//Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel."
            ac1 "//This layout intentionally reserves the 'r' channel for (optional) occlusion map data"
            ac1 "vec4 mrSample = texture2D(s_metallic_roughness, varyings.texcoord0);"
            ac1 "mi.perceptual_roughness *= mrSample.g;"
            ac1 "mi.metallic *= mrSample.b;"
        end

        ac1 "mi.perceptual_roughness  = clamp(mi.perceptual_roughness, 1e-6, 1.0);"
        ac1 "mi.metallic              = clamp(mi.metallic, 1e-6, 1.0);"

        ac0 "\n"
        --occlusion
        ac1 "mi.occlusion = u_occlusion_strength;"
        if varyings.v_texcoord0 and properties.s_occlusion then
            ac1 "mi.occlusion *= texture2D(s_occlusion,  varyings.texcoord0).r;"
        end

        local isdoublesize = state.CULL == "NONE"

        --normal
        if varyings.v_normal then
            ac1 "mi.gN = normalize(varyings.normal);"
            if properties.s_normal and varyings.v_texcoord0 then
                if varyings.v_tangent and varyings.v_bitangent then
                    ac1 "mi.T = normalize(varyings.tangent);"
                    ac1 "mi.B = normalize(varyings.bitangent);"
                    ac1 "mat3 tbn = mat3(mi.T, mi.B, mi.gN);"
                else
                    ac1 "mat3 tbn = cotangent_frame(mi.gN, varyings.posWS, varyings.texcoord0);"
                    ac1 "mi.T = tbn[0];"
                    ac1 "mi.B = tbb[1];"
                end
                ac0 "\n"
                ac1 "mediump vec3 normalTS = fetch_normal_from_tex(s_normal, varyings.texcoord0);"
                ac1 "mi.N = normalize(mul(normalTS, tbn));// same as: mul(transpose(tbn), normalTS)"
            else
                ac1 "mi.N = mi.gN;"
            end

            if isdoublesize then
                ac1 "if (!varyings.is_frontfacing){"
                if varyings.v_tangent then
                    ac2 "mi.T = -mi.T;"
                    ac2 "mi.B = -mi.B;"
                end
                ac2 "mi.N  = -mi.N;"
                ac2 "mi.gN = -mi.gN;"
                ac1 "}" -- is_frontfacing
            end
        end

        --bend normal
        if fx.ENABLE_BENT_NORMAL then
            ac1 "const vec3 bent_normalTS = vec3(0.0, 1.0, 0.0); //TODO: need bent_normal should come from ssao or other place"
            ac1 "mi.bent_normal = bent_normalTS;"
        end

        ac1 "build_material_info(mi);"
        ac1 "fsoutput.color = compute_lighting(mi);"
    else
        ac1 "fsoutput.color = mul_inverse_tonemap(mi.basecolor + mi.emissive);"
    end

    ac0 "}\n"   --end CUSTOM_FS
    return table.concat(d, "\n")
end

local function build_vsinputoutput(inputs, varyings)
    local input = table.concat(inputs, "\n")
    local varying = table.concat(varyings, "\n")

    return ("%s\n\n%s"):format(input, varying)
end

local function build_fsinputoutput(results)
    local fsoutput = {}
    for i=1, #results.varyings-1 do
        fsoutput[i] = results.varyings[i]
    end

    assert(results.varyings[#results.varyings]:match "};$")

    fsoutput[#fsoutput+1] = "\tvec4 frag_coord;"
    fsoutput[#fsoutput+1] = "\tbool is_frontfacing;"

    fsoutput[#fsoutput+1] = [[};
struct FSOutput{
    vec4 color;
};
]]
    return table.concat(fsoutput, "\n")
end

local function build_fs_assignments(mat, varyings, varying_assignments)
    local assignments = {}
    local fsac1 = code_gen(assignments, 1)

    for _, v in ipairs(varying_assignments) do
        local lhs, rhs = v:match "([%w_]+)%s*=%s*varyings%.([%w_]+)"
        assert(lhs and rhs and lhs:match "v_([%w_]+)" == rhs)
        fsac1(("varyings.%s = %s;"):format(rhs, lhs))
    end

    if varyings.v_texcoord0 then
        if mat.fx.setting.uv_motion then
            fsac1 "varyings.texcoord0 = uv_motion(varyings.texcoord0);";
        else
            fsac1 "varyings.texcoord0 = varyings.texcoord0;";
        end
    end

    fsac1 "varyings.frag_coord = gl_FragCoord;"
    local isdoublesize = mat.state.CULL == "NONE"
    if isdoublesize then
        fsac1 "varyings.is_frontfacing = gl_FrontFacing;"
    end

    return assignments
end

local function build_fx_content(inputfolder, mat, varyings, results)
    local inputdecl         = table.concat(results.input_decls, " ")
    local diinputdecl       = table.concat(results.di_input_decls, " ")
    local varyingdecl       = table.concat(results.varying_decls, " ")

    local vs_properties_content, fs_properties_content = generate_properties(mat)
    return {
        vs = {
            ["@VSINPUT_VARYING_DEFINE"] = ("$input %s\n$output %s\n"):format(inputdecl, varyingdecl),
            ["@VSINPUTOUTPUT_STRUCT"]   = build_vsinputoutput(results.inputs, results.varyings),
            ["@VS_PROPERTY_DEFINE"]     = vs_properties_content,
            ["@VS_FUNC_DEFINE"]         = build_vs_code(inputfolder, mat, varyings),
            ["@VSINPUT_INIT"]           = table.concat(results.input_assignments, "\n"),
            ["@OUTPUT_VARYINGS"]        = table.concat(results.varying_assignments, "\n"),
        },
        di = {
            ["@VSINPUT_VARYING_DEFINE"] = ("$input %s\n$output %s\n"):format(diinputdecl, varyingdecl),
            ["@VSINPUTOUTPUT_STRUCT"]   = build_vsinputoutput(results.di_inputs, results.varyings),
            ["@VS_PROPERTY_DEFINE"]     = vs_properties_content,
            ["@VS_FUNC_DEFINE"]         = build_vs_code(inputfolder, mat, varyings, true),
            ["@VSINPUT_INIT"]           = table.concat(results.di_input_assignments, "\n"),
            ["@OUTPUT_VARYINGS"]        = table.concat(results.varying_assignments, "\n"),
        },
        fs = {
            ["@FSINPUT_VARYINGS_DEFINE"]= "$input " .. varyingdecl,
            ["@FSINPUTOUTPUT_STRUCT"]   = build_fsinputoutput(results),
            ["@FS_PROPERTY_DEFINE"]     = fs_properties_content,
            ["@FS_FUNC_DEFINE"]         = build_fs_code(inputfolder, mat, varyings),
            ["@FSINPUT_FROM_VARYING"]   = table.concat(build_fs_assignments(mat, varyings, results.varying_assignments), "\n"),
        }
    }
end

local function write_varying_def_sc(def_filename, varying_def)
    write_file(def_filename, table.concat(varying_def, "\n"))
    return def_filename:string()
end

local function macros_from_setting(setting, m)
    if setting.lighting == "off" then
        m[#m+1] = "MATERIAL_UNLIT=1"
    end

    if ENABLE_SHADOW and setting.receive_shadow == "on" then
        m[#m+1] = "ENABLE_SHADOW=1"
        m[#m+1] = FILTER_MODE_MACROS[FILTER_MODE]
        local mm = SHADOW_FILTER_MACROS[FILTER_MODE]
        if mm then
            table.move(mm, 1, #mm, #m+1, m)
        end
    end

    if setting.position_only then
        m[#m+1] = "POSITION_ONLY=1"
    end

    if setting.uv_motion then
        m[#m+1] = "UV_MOTION=1"
    end

    if setting.threadsize then
        m[#m+1] = "THREAD_NUM_X=" .. setting.threadsize[1]
        m[#m+1] = "THREAD_NUM_Y=" .. setting.threadsize[2]
        m[#m+1] = "THREAD_NUM_Z=" .. setting.threadsize[3]
    end
end

local function build_fx_macros(mat, varyings)
    mat.fx.macros = mat.fx.macros or {}
    local m = mat.fx.macros
    for k in pairs(varyings) do
        local v = L.SEMANTICS_INFOS[k]
        if v then
            m[#m+1] = v.macro
        end
    end

    if varyings.a_tangent and varyings.a_tangent.pack_from_quat then
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

    if varyings.a_indices and varyings.a_weight and (not mat.fx.setting.no_skinning) then
        m[#m+1] = "GPU_SKINNING=1"
    end

    macros_from_setting(mat.fx.setting, m)
end

local function check_shader(shader, stage)
    if stage == "vs" then
        if not shader:match "CUSTOM_VS_POSITION" then
            error "Need define 'CUSTOM_VS_POSITION'"
        end
    elseif stage == "fs" then
        if not shader:match "CUSTOM_FS" then
            error "Need define 'CUSTOM_FS'"
        end
    end

    return shader
end

local function gen_shader(setting, fx, stage, shaderdefined)
    local si = DEF_SHADER_INFO[stage]
    if not si then
        --TODO: can 'depth' stage to generated shader??
        assert(fx[stage] and stage == "depth")
        return
    end
    local shader = check_shader(si.template:gsub("@[%w_]+", shaderdefined[stage]), stage)

    local filename = setting.scpath / si.filename:format(sha1(shader))

    if not lfs.exists(filename) then
        write_file(filename, shader)
    end
    if fx[stage] then
        error "vs/fs should not define when use genertaed shader"
    end
    fx[stage] = filename:string()
end

local function find_stages(fx)
    if fx.shader_type == "COMPUTE" then
        return {cs = true}
    end

    if fx.shader_type ~= "PBR" and (not (fx.vs or fx.depth)) then
        error "At least define 'vs' or 'depth' stage"
    end

    local stages = {}
    if fx.shader_type == "PBR" then
        stages.di = true
    end
    if fx.vs or fx.shader_type == "PBR" then
        stages.vs = true
    end
    if fx.fs or fx.shader_type == "PBR" then
        stages.fs = true
    end
    if fx.depth then
        stages.depth = true
    end

    return stages
end

local function gen_fx(setting, input, output, mat)
    local inputfolder = lfs.path(input):parent_path()
    local fx = mat.fx
    local stages = find_stages(fx)

    local varyings = read_varyings_input(setting, inputfolder, fx)
    local results
    if varyings then
        results = build_input_var(varyings)
        fx.varying_path     = write_varying_def_sc(output / "varying.def.sc", results.varying_def)
        fx.di_varying_path  = write_varying_def_sc(output / "varying.di.def.sc", results.di_varying_def)
    end

    if fx.shader_type == "PBR" then
        if not varyings then
            error(("Material file:%s, shader_type == 'PBR' should define 'varyings' in material file"):format(input))
        end
        local fxcontent = build_fx_content(inputfolder, mat, varyings, results)
        build_fx_macros(mat, varyings)
        for stage in pairs(stages) do
            gen_shader(setting, fx, stage, fxcontent)
        end
    end

    return stages
end

return {
    gen_fx              = gen_fx,
    DEF_PBR_UNIFORM     = DEF_PBR_UNIFORM,
    LOCAL_SHADER_BASE   = LOCAL_SHADER_BASE,
    read_varyings       = read_varyings_input,
    macros_from_setting = macros_from_setting,
}