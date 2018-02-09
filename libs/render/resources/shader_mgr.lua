local require = import and import(...) or require

local bgfx = require "bgfx"
local hw_caps = require "render.hardware_caps"

-- init
local shader_path
local vs_shaders = {}
local fs_shaders = {}
local programs = {}

local shader_mgr = {
      
}

local function load_shader(name)
    if shader_path == nil then
        local path = {
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
        
        local caps = hw_caps.get()
        shader_path = "assets/shaders/".. (assert(path[caps.rendererType])) .."/"
    end
    local filename = shader_path .. name .. ".bin"
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
        return programLoadEx(vs,fs, uniform)
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


return shader_mgr