local cr = require "thread.compile"
local serialize = import_package "ant.serialize"
local bgfx = require "bgfx"
local fastio = require "fastio"

local PM = require "programan.server"
PM.program_init{
    max = bgfx.get_caps().limits.maxPrograms - bgfx.get_stats "n".numPrograms
}

local function readall(filename)
    return fastio.readall(cr.compile(filename))
end

local function uniform_info(shader, uniforms, mark)
    local shader_uniforms = bgfx.get_shader_uniforms(shader)
    if shader_uniforms then
        for _, h in ipairs(shader_uniforms) do
            local name, type, num = bgfx.get_uniform_info(h)
            if not mark[name] then
                mark[name] = true
                uniforms[#uniforms + 1] = { handle = h, name = name, type = type, num = num }
            end
        end
    end
end

local function loadShader(shaderfile)
    if shaderfile then
        local h = bgfx.create_shader(bgfx.memory_buffer(readall(shaderfile)))
        bgfx.set_name(h, shaderfile)
        return h
    end
end

local function fetch_uniforms(h, ...)
    local uniforms, mark = {}, {}
    local function fetch_uniforms_(h, ...)
        if h then
            uniform_info(h, uniforms, mark)
            return fetch_uniforms_(...)
        end
    end
    fetch_uniforms_(h, ...)
    return uniforms
end

local function from_handle(handle)
    local pid = PM.program_new()
    PM.program_set(pid, handle)
    return pid
end

local function createRenderProgram(fxcfg)
    local vh = loadShader(fxcfg.vs)
    local fh = loadShader(fxcfg.fs)
    local prog = bgfx.create_program(vh, fh, false)
    if prog then
        return {
            shader_type = fxcfg.shader_type,
            setting     = fxcfg.setting or {},
            vs          = vh,
            fs          = fh,
            prog        = prog,
            uniforms    = fetch_uniforms(vh, fh),
        }
    else
        error(("create program failed, filename:%s"):format(fxcfg.vs))
    end
end

local function createComputeProgram(fxcfg)
    local ch = loadShader(fxcfg.cs)
    local prog = bgfx.create_program(ch, false)
    if prog then
        return {
            shader_type = fxcfg.shader_type,
            setting     = fxcfg.setting or {},
            cs          = ch,
            prog        = prog,
            uniforms    = fetch_uniforms(ch),
        }
    else
        error(string.format("create program failed, cs:%d", ch))
    end
end

local S = require "thread.main"

local function is_compute_material(fxcfg)
    return fxcfg.shader_type == "COMPUTE"
end

local function absolute_path(path, base)
    if path:sub(1,1) == "/" then
        return path
    end
    return base:match "^(.-)[^/|]*$" .. (path:match "^%./(.+)$" or path)
end

local MATERIALS = {}

local MATERIAL_MARKED = {}

local function build_fxcfg(filename, fx)
    local function stage_filename(stage)
        if fx[stage] then
            return ("%s|%s.bin"):format(filename, stage)
        end
    end
    return {
        shader_type = fx.shader_type,
        setting = fx.setting,
        vs = stage_filename "vs",
        fs = stage_filename "fs",
        cs = stage_filename "cs",
    }
end

local function create_fx(cfg)
    return is_compute_material(cfg) and 
        createComputeProgram(cfg) or
        createRenderProgram(cfg)
end

local function material_create(filename)
    local material = serialize.parse(filename, readall(filename .. "|main.cfg"))
    local fxcfg = build_fxcfg(filename, assert(material.fx, "Invalid material"))
    material.fx = create_fx(fxcfg)
    if material.properties then
        for _, v in pairs(material.properties) do
            if v.texture then
                v.type = 't'
                local texturename = absolute_path(v.texture, filename)
                v.value = S.texture_create_fast(texturename)
            elseif v.image then
                v.type = 'i'
                local texturename = absolute_path(v.image, filename)
                v.value = S.texture_create_fast(texturename)
            elseif v.buffer then
                v.type = 'b'
            end
        end
    end

    material.fx.prog = from_handle(material.fx.prog)
    return material, fxcfg
end

function S.material_create(filename)
    local material, fxcfg = material_create(filename)
    local pid = material.fx.prog
    MATERIALS[pid] = {
        filename = filename,
        material = material,
        cfg      = fxcfg,
    }
    return material
end

function S.material_mark(pid)
    MATERIAL_MARKED[pid] = true
end

function S.material_unmark(pid)
    MATERIAL_MARKED[pid] = nil
end

local function material_destroy(material)
    local fx = material.fx

    -- why? PM only keep 16 bit data(it's bgfx handle data), but program type in high 16 bit with int32 data, we need to recover the type for handle when destroy
    local function make_prog_handle(h)
        assert(h ~= 0xffff)
        --handle type, see: luabgfx.h:7, with enum BGFX_HANDLE
        local PROG_TYPE<const> = 1
        return (PROG_TYPE<<16)|h
    end

    --DO NOT clean fx.prog to nil
    local h = PM.program_reset(fx.prog)
    bgfx.destroy(make_prog_handle(h))

    local function destroy_stage(stage)
        if fx[stage] then
            bgfx.destroy(fx[stage])
            fx[stage] = nil
        end
    end
    destroy_stage "vs"
    destroy_stage "fs"
    destroy_stage "cs"
end

--the serive call will fully remove this material, both cpu and gpu side
function S.material_destroy(material)
    local pid = material.fx.prog
    assert(MATERIALS[pid])
    MATERIALS[pid] = nil

    material_destroy(material)
end

-- local REMOVED_PROGIDS = {}
-- local REQUEST_PROGIDS = {}

function S.material_check()
    local removed = PM.program_remove()
    if removed then
        for _, removeid in ipairs(removed) do
            if nil == MATERIAL_MARKED[removeid] then
                local mi = assert(MATERIALS[removeid])
                log.info(("Remove prog:%d, from file:%s"):format(removeid, mi.filename))
                -- we just destroy bgfx program handle and shader handles, but not remove 'material' from cpu side
                material_destroy(mi.material)
            end
        end
    end

    local requested = PM.program_request()
    if requested then
        for _, requestid in ipairs(requested) do
            local mi = MATERIALS[requestid]
            if mi then
                assert(not MATERIAL_MARKED[requestid])
                log.info(("Recreate prog:%d, from file:%s"):format(requestid, mi.filename))
                local newfx = create_fx(mi.cfg)
                PM.program_set(requestid, newfx.prog)
                newfx.prog = requestid
        
                mi.material.fx = newfx
            else
                log.info(("Can not create prog:%d, it have been fully remove by 'S.material_destroy'"):format(requestid))
            end
        end
    end
end
