local sha1          = require "sha1"
local lfs           = require "bee.filesystem"
local fs            = require "filesystem"
local vfs           = require "vfs"
local datalist      = require "datalist"

local serialize     = import_package "ant.serialize"
local fastio        = serialize.fastio

local SC_ROOT       = lfs.path(vfs.repopath()) / ".build" / "sc"
if not lfs.exists(SC_ROOT) then
    lfs.create_directories(SC_ROOT)
end

local SHADER_BASE <const>           = "/pkg/ant.resources/shaders"

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
        template                = fastio.readall_s(SHADER_BASE.."/default/vs_default.sc"),
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
        template                = fastio.readall_s(SHADER_BASE.."/default/fs_default.sc"),
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

local function read_varyings_input(inputfolder, fx)
    local varyings = assert(fx.varyings, "Need varyings defined")

    if type(varyings) == "string" then
        local vi = fs.path(varyings)
        if not fs.exists(vi) then
            local p = inputfolder / vi
            if fs.exists(p) then
                vi = p
            else
                error(("invalid varyings file:%s"):format(fx.varyings))
            end
        end
        varyings = datalist.parse(fastio.readall_s(vi))
    else
        assert(type(varyings) == "table")
    end

    return parse_varyings_input(varyings)
end

local function write_file(filename, c)
    local f<close> = io.open(filename, "wb") or error(("Failed to open filename:%s"):format(filename))
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

local function build_input_var(varyingcontent)
    local varying_def_decls = {}
    local input_decls, varying_decls = {}, {}
    local input_assignments, varying_assignments = {}, {}
    local inputs = {
        "struct VSInput {",
    }

    local varyings = {
        "struct Varyings {",
    }

    local shaderfmt = "%s %s;"
    for k, v in sortpairs(varyingcontent) do
        varying_def_decls[#varying_def_decls+1] = ("%s %s : %s;"):format(v.type, k, v.bind)
        if is_input_varying(k) then
            inputs[#inputs+1]           = shaderfmt:format(v.type, k)
            input_decls[#input_decls+1] = k
            input_assignments[#input_assignments+1] = ("vsinput.%s = %s;"):format(k, k)
        else
            assert(is_output_varying(k, v))
            varyings[#varyings+1]           = shaderfmt:format(v.type, k)
            varying_decls[#varying_decls+1] = k
            varying_assignments[#varying_assignments+1] = ("%s = vsoutput.%s;"):format(k, k)
        end
    end

    inputs[#inputs+1]       = "};"
    varyings[#varyings+1]   = "};"
    
    return {
        varying_def     = varying_def_decls,
        inputs          = inputs,
        varyings        = varyings,
        input_decls     = input_decls,
        varying_decls   = varying_decls,
        input_assignments = input_assignments,
        varying_assignments = varying_assignments,
    }
end

local function build_shader_content(fx, varyings, results)
    local inputdecl     = table.concat(results.input_decls, " ")
    local varyingdecl   = table.concat(results.varying_decls, " ")
    local inputassignment = table.concat(results.input_assignments, "\n")
    local varyingassignment = table.concat(results.varying_assignments, "\n")
    local vs = {
        ["@VSINPUT_VARYING_DEFINE"] = ("$input %s\n$output %s\n"):format(inputdecl, varyingdecl),
        ["@VSINPUTOUTPUT_STRUCT"]   = table.concat(results.inputs, "\n"),
        ["@VS_PROPERTY_DEFINE"]     = generate_properties("vs", fx.properties),
        ["@VS_FUNC_DEFINE"]         = fx.vs_code,
        ["@VSINPUT_INIT"]           = inputassignment,
        ["@OUTPUT_VARYINGS"]        = varyingassignment,
    }

    local fsinput_assignments = {}
    for _, v in ipairs(results.varying_assignments) do
        local lhs, rhs = v:match "(%w+)%s*=%s*vsoutput%.(%w+)"
        assert(lhs and rhs and lhs == rhs)
        fsinput_assignments[#fsinput_assignments+1] = ("fsinput.%s = %s;"):format(rhs, lhs)
    end

    local fs = {
        ["@FSINPUT_VARYINGS_DEFINE"]= "$input " .. varyingdecl,
        ["@FSINPUTOUTPUT_STRUCT"]   = table.concat(results.varyings, "\n"),
        ["@FS_PROPERTY_DEFINE"]     = generate_properties("fs", fx.properties),
        ["@FS_FUNC_DEFINE"]         = fx.fs_code,
        ["@FSINPUT_FROM_VARYING"]   = table.concat(fsinput_assignments, "\n"),
    }

    return vs, fs
end

local function gen_fx(input, output, fx)
    local varyings = parse_varyings_input(read_varyings_input(input, fx))

    local results = build_input_var(varyings)

    local varying_path = output / "varying.def.sc"
    write_file(varying_path, table.concat(results.varying_def, ""))
    fx.varying_path = varying_path:string()

    return build_shader_content(fx, results)
end

local function gen_shader(fx, stage, shaderdefined)
    local si = assert(DEF_SHADER_INFO[stage])

    local function generate_shader(template, content)
        return template:gsub("@%w+", content)
    end

    local shader = generate_shader(si.template, shaderdefined[stage])

    local fn = si.filename:format(sha1(shader))
    local filename = SC_ROOT / fn

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
    gen_fx          = gen_fx,
    gen_shader      = gen_shader,
    DEF_PBR_UNIFORM = DEF_PBR_UNIFORM,
    SHADER_BASE     = SHADER_BASE,
}