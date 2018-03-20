local require = import and import(...) or require

local bgfx = require "bgfx"
local hw_caps = require "render.hardware_caps"
local fs = require "filesystem"

-- init
local function get_caps_path()
    local caps = hw_caps.get()
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
local caps_bin_path = get_caps_path()
local src_path = "src"
local shader_path = shader_asset_path .. "/" .. caps_bin_path .. "/"
local shader_mgr = {}

local function compile_shader(filename, outfile)
    local toolset = require "editor.toolset"
    local config = toolset.load_config()

    if next(config) == nil then
        return false, "load_config file failed, 'bin/iup.exe tools/config.lua' need to run first"
    end

    config.dest = outfile    
    return toolset.compile(filename, config)
end

local function check_compile_shader(name, outfile)
    local _, ext = name:match("([%w_/\\]+)%.(sc)")
    if ext ~= nil then
        local fullname = shader_asset_path .. "/" .. src_path .. "/" .. name        
        local success, msg = compile_shader(fullname, outfile)
        if not success then
            log(string.format("try compile from file %s, but failed, error message : \n%s", filename, msg))
            return false
        end
    end

    return true
end

local function remove_ext(name)
    local path, ext = name:match("([%w_/\\]+)%.([%w_]+)$")
    if ext ~= nil then
        return path
    end

    return name
end

local function parent_path(fullname)
    local path = fullname:match("^([%w_/\\]+)[/\\][%w_.]+")
    return path
end

local function join_path(p0, p1)
    local lastchar = p0[-1]

    if lastchar ~= '/' and lastchar ~= '\\' then
        return string.format("%s/%s", p0, p1)
    end
    return p0 .. p1
end

local function trim_slash(fullpath)
    return fullpath:match("^%s*[/\\]*([%w_/\\]+)[/\\]")
end

local function create_dirs(fullpath)    
    fullpath = trim_slash(fullpath)
    local cwd = fs.currentdir()
    for m in fullpath:gmatch("[%w_]+") do
        cwd = join_path(cwd, m)
        if not fs.exist(cwd) then        
            fs.mkdir(cwd)
        end
    end
end

local function load_shader(name)
    create_dirs(join_path(shader_path, parent_path(name)))

    local filename = shader_path .. remove_ext(name) .. ".bin"    
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