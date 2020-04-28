local bgfx      = require "bgfx"
local shadermgr = require "shader_mgr"
local fs        = require "filesystem"
local cr        = import_package "ant.compile_resource"
local lfs       = require "filesystem.local"
local thread    = require "thread"

local function load_shader(shaderbin, filename)
    local h = bgfx.create_shader(shaderbin)
    bgfx.set_name(h, filename)
    return {
        handle = h,
        uniforms = bgfx.get_shader_uniforms(h),
    }
end

local function readfile(filename)
	local f = assert(lfs.open(filename, "rb"))
	local data = f:read "a"
	f:close()
	return data
end

return {
    loader = function (fxpath)
        local outpath = cr.compile(fs.path(fxpath):localpath())
        local config = thread.unpack(readfile(outpath / "main.index"))
        local shader = config.shader
        if shader.cs == nil then
            local vs = load_shader(readfile(outpath / "vs"), shader.vs)
            local fs = load_shader(readfile(outpath / "fs"), shader.fs)
            shader.prog, shader.uniforms = shadermgr.create_render_program(vs, fs)
        else
            local cs = load_shader(readfile(outpath / "cs"), shader.cs)
            shader.prog, shader.uniforms = shadermgr.create_compute_program(cs)
            shader.csbin = nil
        end
        return config, 0
    end,

    unloader = function (res)
        local shader = res.shader
        bgfx.destroy(shader.prog)
        res.shader = nil
        res.surface_type = nil
    end
}
