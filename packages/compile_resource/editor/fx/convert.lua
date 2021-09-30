local lfs = require "filesystem.local"
local fs = require "filesystem"
local toolset = require "editor.fx.toolset"
local fxsetting = require "editor.fx.setting"
local SHARER_INC = lfs.absolute(fs.path "/pkg/ant.resources/shaders":localpath())
local setting = import_package "ant.settings".setting

local function DEF_FUNC() end

local SETTING_MAPPING = {
    lighting = function (v)
        if v == "on" then
            return "ENABLE_LIGHTING"
        end
    end,
    shadow_receive = function (v)
        if v == "on" then
            return "ENABLE_SHADOW"
        end
    end,
    skinning = function (v)
        if v == "GPU" then
            return "GPU_SKINNING"
        end
    end,
    depth_type = function (v)
        if v == "linear" then
            return "DEPTH_LINEAR"
        elseif v == "pack_depth" then
            return "PACK_RGBA8"
        end
    end,
    bloom = function (v)
        if v == "on" then
            return "BLOOM_ENABLE"
        end
    end,
    fix_line_width = "FIX_WIDTH",
    subsurface = DEF_FUNC,
    surfacetype = DEF_FUNC,
    shadow_cast = DEF_FUNC,
}

local enable_cs = setting:get 'graphic/lighting/cluster_shading' ~= 0

local function default_macros(setting)
    local m = {
        "ENABLE_SRGB_TEXTURE",
        "ENABLE_SRGB_FB",
        "ENABLE_IBL"
    }

    if enable_cs then
        m[#m+1] = "HOMOGENEOUS_DEPTH=" .. (setting.hd and "1" or "0")
        m[#m+1] = "ORIGIN_BOTTOM_LEFT=" .. (setting.obl and "1" or "0")
        m[#m+1] = "CLUSTER_SHADING"
    end
    return m
end

local function get_macros(s)
    local setting = fxsetting.adddef(s)
    local macros = default_macros(setting)
    for k, v in pairs(setting) do
        local f = SETTING_MAPPING[k]
        if f == nil then
            macros[#macros+1] = k
        else
            local t = type(f)
            if t == "function" then
                macros[#macros+1] = f(v)
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

return function (input, output, setting)
    local stage = input:string():match("/([cfv]s)_[^/]*%.sc$")
    local ok, err, deps = toolset.compile {
        platform = setting.os,
        renderer = setting.renderer,
        input = input,
        output = output / "main.bin",
        includes = {SHARER_INC},
        stage = stage,
        macros = get_macros(setting),
        debug = compile_debug_shader(setting.os, setting.renderer),
    }
    if not ok then
        return false, ("compile failed: " .. input:string() .. "\n\n" .. err)
    end
    return true, deps
end
