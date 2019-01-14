--luacheck: globals log
local log = log and log(...) or print

local bgfx = require "bgfx"
local assetmgr = import_package "ant.asset"
local fs = require "filesystem"
local vfs = require "vfs"

local alluniforms = {}

local shader_mgr = {}
shader_mgr.__index = shader_mgr

local function gen_shader_filepath(pkgname, shadername)
	assert(fs.path(shadername):extension() == fs.path '')
	local shadername_withext = fs.path(shadername .. ".sc")
	local filepath = assetmgr.find_asset_path(pkgname, shadername_withext)
	if filepath then
		return filepath 
	end
	return assetmgr.find_asset_path(pkgname, fs.path "shaders/src" / shadername_withext)
end

local function load_shader(pkgname, name)
	local filepath = gen_shader_filepath(pkgname, name)
	if filepath == nil then
		error(string.format("not found shader file: [%s:%s]", pkgname, name))
	end

	if not fs.vfs then		
		assert(vfs.type(filepath:string() .. ".lk") ~= nil)		
	end	

	local f = assert(io.open(filepath:string(), "rb"))
	local data = f:read "a"
	f:close()
	local h = bgfx.create_shader(data)
	bgfx.set_name(h, name)
	return h    
end

local function load_shader_uniforms(pkgname, name)
    local h = assert(load_shader(pkgname, name))    
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

local function programLoadEx(pkgname, vs, fs, uniform)
    local vsid, u1 = load_shader_uniforms(pkgname, vs)
    local fsid, u2
    if fs then
        fsid, u2 = load_shader_uniforms(pkgname, fs)
    end
    uniform_info(uniform, u1)
    if u2 then
        uniform_info(uniform, u2)
    end
    return bgfx.create_program(vsid, fsid, true), uniform
end

function shader_mgr.programLoad(pkgname, vs,fs, uniform)
    if uniform then
        local prog = programLoadEx(pkgname, vs,fs, uniform)
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
        local vsid = load_shader(pkgname, vs)
        local fsid = fs and load_shader(pkgname, fs)          
        return bgfx.create_program(vsid, fsid, true)
    end
end

function shader_mgr.computeLoad(pkgname, cs)
    local csid = load_shader(pkgname, cs)
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