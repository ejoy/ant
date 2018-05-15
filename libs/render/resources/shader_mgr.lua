local require = import and import(...) or require
local log = log and log(...) or print

local bgfx = require "bgfx"
local baselib = require "bgfx.baselib"
local rhwi = require "render.hardware_interface"
local toolset = require "editor.toolset"
local path = require "filesystem.path"

-- init
local function get_shader_subpath()
    local caps = rhwi.get_caps()
    local paths = {
        NOOP       = "dx9",
        DIRECT3D9  = "dx9",
        DIRECT3D11 = "dx11",
        DIRECT3D12 = "dx11",
        GNM        = "pssl",
        METAL      = "metal",
        OPENGL     = "glsl",
        OPENGLES   = "essl",
        VULKAN     = "spirv",
    }

    return assert(paths[caps.rendererType])
end

local shader_asset_path = "assets/shaders"
local src_path = "src"

local function get_shader_path()
    local caps_bin_path = get_shader_subpath()
    return path.join(shader_asset_path, caps_bin_path)
end

local function get_compile_renderer_name()
    local caps = rhwi.get_caps()
    local rendertype = caps.rendererType
    local platform = baselib.platform_name

    if  rendertype == "DIRECT3D9" then
        return "d3d9"
    end

    if  rendertype == "DIRECT3D11" or
        rendertype == "DIRECT3D12" then
        return "d3d11"
    end

    return platform
end


local uniforms = {}

local shader_mgr = {}
shader_mgr.__index = shader_mgr

local function compile_shader(filename, outfile)
    local config = toolset.load_config()

    if next(config) == nil then
        return false, "load_config file failed, 'bin/iup.exe tools/config.lua' need to run first"
    end

    config.dest = outfile
    return toolset.compile(filename, config, get_compile_renderer_name())
end

local function check_compile_shader(name, outfile)
    local ext = path.ext(name)
    if ext and ext:lower() == "sc" then
        path.create_dirs(path.parent(outfile))
        local fullname = path.join(shader_asset_path, src_path, name)
        local success, msg = compile_shader(fullname, outfile)
        if not success then
            print(string.format("try compile from file %s, but failed, error message : \n%s", fullname, msg))
            return false
        end
    end

    return true
end

local function load_shader(name)
    local filename = path.join(get_shader_path(), path.remove_ext(name)) .. ".bin"
    if not check_compile_shader(name, filename) then
        return nil
    end

    local f = assert(io.open(filename, "rb"))
    local data = f:read "a"
    f:close()
    local h = bgfx.create_shader(data)
    bgfx.set_name(h, filename)
    return h
end

local function load_shader_uniforms(name)
    local h = load_shader(name)
    local uniforms = bgfx.get_shader_uniforms(h)
    return h, uniforms
end

local function uniform_info(uniforms, handles)
    for _, h in ipairs(handles) do
        local name, type, num = bgfx.get_uniform_info(h)
        if uniforms[name] == nil then
            uniforms[name] = { handle = h, name = name, type = type, num = num }
        end
    end
end

local function programLoadEx(vs,fs, uniform)
    local vsid, u1 = load_shader_uniforms(vs)
    local fsid, u2
    if fs then
        fsid, u2 = load_shader_uniforms(fs)
    end
    uniform_info(uniform, u1)
    if u2 then
        uniform_info(uniform, u2)
    end
    return bgfx.create_program(vsid, fsid, true), uniform
end

function shader_mgr.programLoad(vs,fs, uniform)
    if uniform then
        local prog = programLoadEx(vs,fs, uniform)
        if prog then
            for k, v in pairs(uniform) do
                local old_u = uniforms[k]
                if old_u and old_u.type ~= v.type and old_u.num ~= v.num then
                    log(string.format([[previous has been defined uniform,
                                    nameis : %s, type=%s, num=%d, replace as : type=%s, num=%d]],
                                    old_u.name, old_u.type, old_u.num, v.type, v.num))
                end

                uniforms[k] = v
            end
        end
        return prog
    else
        local vsid = load_shader(vs)
        local fsid = fs and load_shader(fs)
        return bgfx.create_program(vsid, fsid, true)
    end
end

function shader_mgr.computeLoad(cs)
    local csid = load_shader(cs)
    return bgfx.create_program(csid, true)
end

function shader_mgr.get_uniform(name)
    return uniforms[name]
end

return shader_mgr