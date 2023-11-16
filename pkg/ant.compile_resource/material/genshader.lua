local sha1          = require "sha1"
local lfs           = require "bee.filesystem"
local vfs           = require "vfs"

local serialize     = import_package "ant.serialize"
local fastio        = serialize.fastio

local SC_ROOT       = lfs.path(vfs.repopath()) / ".build" / "sc"
if not lfs.exists(SC_ROOT) then
    lfs.create_directories(SC_ROOT)
end

local SHADER_BASE <const>           = "/pkg/ant.resources/shaders"

local DEF_SHADER_INFO <const> = {
    vs = {
        CUSTOM_PROP_KEY = "%$%$CUSTOM_VS_PROP%$%$",
        CUSTOM_FUNC_KEY = "%$%$CUSTOM_VS_FUNC%$%$",
        content = fastio.readall_s(SHADER_BASE.."/default/vs_default.sc"),
        filename = "vs_%s.sc",
    },
    fs = {
        CUSTOM_PROP_KEY = "%$%$CUSTOM_FS_PROP%$%$",
        CUSTOM_FUNC_KEY = "%$%$CUSTOM_FS_FUNC%$%$",
        content = fastio.readall_s(SHADER_BASE.."/default/fs_default.sc"),
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

local function create_PBR_shader(fx, stage, properties)
    local si = assert(DEF_SHADER_INFO[stage])
    local nc = generate_shader(si, fx[stage .. "_code"], properties)
    local fn = si.filename:format(sha1(nc))
    local filename = SC_ROOT / fn

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

return {
    gen             = create_PBR_shader,
    DEF_PBR_UNIFORM = DEF_PBR_UNIFORM,
    SHADER_BASE     = SHADER_BASE,
}