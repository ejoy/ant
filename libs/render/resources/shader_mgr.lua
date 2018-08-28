local require = import and import(...) or require
local log = log and log(...) or print

local bgfx = require "bgfx"

local toolset = require "editor.toolset"
local path = require "filesystem.path"
local assetmgr = require "asset"
local fs = require "filesystem"
local fu = require "filesystem.util"

local baselib = require "bgfx.baselib"
local rhwi = require "render.hardware_interface"

local alluniforms = {}

local shader_mgr = {}
shader_mgr.__index = shader_mgr

local rt_subpath = nil

function shader_mgr.get_shader_rendertype_path()
	if rt_subpath then
		return rt_subpath
	end

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

	rt_subpath = assert(paths[caps.rendererType])
	return rt_subpath	
end

function shader_mgr.get_compile_renderer_name()
    local caps = rhwi.get_caps()
    local rendertype = caps.rendererType
    local platform = string.lower(baselib.platform_name)

    if  rendertype == "DIRECT3D9" then
        return "d3d9"
    end

    if  rendertype == "DIRECT3D11" or
        rendertype == "DIRECT3D12" then
        return "d3d11"
	end
	
    return platform
end

local function get_full_filename(relative_name)
	if path.ext(relative_name) == nil then
		relative_name = relative_name .. ".sc"
	end

	local subshaderfolder = "shaders/src"
	local filename = path.join(subshaderfolder, relative_name)
	return assetmgr.find_valid_asset_path(filename)

	-- local rt_path = shader_mgr.get_shader_rendertype_path()
	-- return assetmgr.find_valid_asset_path(path.join("shaders", rt_path, relative_name .. ".bin"))
end

local function load_shader(name)
	local filename = get_full_filename(name)	
	local f = assert(io.open(assert(filename), "rb"))
	local data = f:read "a"
	f:close()
	local h = bgfx.create_shader(data)
	bgfx.set_name(h, name)
	return h    
end

local function load_shader_uniforms(name)
    local h = load_shader(name)
    assert(h)
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
                local old_u = alluniforms[k]
                if old_u and old_u.type ~= v.type and old_u.num ~= v.num then
                    log(string.format([[previous has been defined uniform, 
                                    nameis : %s, type=%s, num=%d, replace as : type=%s, num=%d]],
                                    old_u.name, old_u.type, old_u.num, v.type, v.num))
                end

                alluniforms[k] = v
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
    return alluniforms[name]
end

-- function shader_mgr.add_uniform(name, type, num)
-- 	local uh = alluniforms[name]
-- 	if uh == nil then
-- 		num = num or 1
-- 		uh = bgfx.create_uniform(name, type, num)
-- 		alluniforms[name] = { handle = uh, name = name, type = type, num = num }
-- 	end
-- 	return uh
-- end

return shader_mgr