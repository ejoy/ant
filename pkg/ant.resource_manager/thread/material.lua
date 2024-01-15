local bgfx = require "bgfx"
local serialize = import_package "ant.serialize"
local aio = import_package "ant.io"

local PM = require "programan.server"
PM.program_init{
    max = bgfx.get_caps().limits.maxPrograms - bgfx.get_stats "n".numPrograms
}

local function get_fx(fx, type)
    if type == "draw" then
        return fx
    elseif type == "depth" then
        return fx.depth
    elseif type == "draw_indirect" then
        return fx.di
    else
        error("error program type!\n")
    end
end

local function uniform_info(shader, uniforms)
    local shader_uniforms = bgfx.get_shader_uniforms(shader)
    if shader_uniforms then
        for _, h in ipairs(shader_uniforms) do
            local name, type, num = bgfx.get_uniform_info(h)
            local u = uniforms[name]
            if u then
                if u.handle ~= h or u.type ~= type or u.num ~= num then
                    error(("same uniform name, but with different field: handle:%d, %d, type:%d, %d, num: %d, %d"):format(u.handle, h, u.type, type, u.num, num))
                end
            else
                uniforms[name] = { handle = h, name = name, type = type, num = num }
            end
        end
    end
end

local function loadShader(shaderfile)
    if shaderfile then
        local h = bgfx.create_shader(bgfx.memory_buffer(aio.readall(shaderfile)))
        bgfx.set_name(h, shaderfile)
        return h
    end
end

local function fetch_uniforms(h, ...)
    local uniforms = {}
    local function fetch_uniforms_(h, ...)
        if h then
            uniform_info(h, uniforms)
            return fetch_uniforms_(...)
        end
    end
    fetch_uniforms_(h, ...)
    return uniforms
end

local function from_handle(handle)
    if handle then
        local pid = PM.program_new()
        PM.program_set(pid, handle)
        return pid
    end
end

local function createRenderProgram(fxcfg)
    local dh, depth_prog, depth_uniforms
    if fxcfg.depth then
        dh = loadShader(fxcfg.depth)
        depth_prog = bgfx.create_program(dh, false)
        if nil == depth_prog then
            error "Depth shader provided, but create depth program faield"
        end

        depth_uniforms = fetch_uniforms(dh)
    end

    local prog, uniforms, vh, fh, di_prog, di_vh
    if fxcfg.vs or fxcfg.fs then
        vh = loadShader(fxcfg.vs)
        fh = loadShader(fxcfg.fs)
        prog = bgfx.create_program(vh, fh, false)
        uniforms = fetch_uniforms(vh, fh)
    end
    if fxcfg.di then
        di_vh = loadShader(fxcfg.di)
        di_prog = bgfx.create_program(di_vh, fh, false)
    end

    if not (prog or depth_prog or di_prog) then
        error(("create program failed, filename:%s"):format(fxcfg.vs))
    end

    local fx = {
        shader_type     = fxcfg.shader_type,
        setting         = fxcfg.setting or {},
        vs              = vh,
        fs              = fh,
        prog            = prog,
        uniforms        = uniforms,
        varyings        = fxcfg.varyings,
    }

    if depth_prog then
        fx.depth = {
            vs      = dh,
            prog    = depth_prog,
            uniforms= depth_uniforms,
            varyings= fxcfg.depth_varyings,
        }
    end

    if di_prog then
        fx.di = {
            shader_type     = fxcfg.shader_type,
            setting         = fxcfg.setting or {},
            vs              = di_vh,
            fs              = fh,
            prog            = di_prog,
            uniforms        = uniforms,
            varyings        = fxcfg.varyings,
        }
    end

    return fx
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

local function normalize_path(fullname)
	local first = (fullname:sub(1, 1) == "/") and "/" or ""
	local last = (fullname:sub(-1, -1) == "/") and "/" or ""
	local t = {}
	for m, seq in fullname:gmatch("([^/|]+)([/|]?)") do
		if m == ".." and next(t) then
			table.remove(t, #t)
			table.remove(t, #t)
		elseif m ~= "." then
			table.insert(t, m)
			table.insert(t, seq)
		end
	end
	return first .. table.concat(t) .. last
end

local function absolute_path(path, base)
    if path:sub(1,1) == "/" then
        return path
    end
    return normalize_path(base:match "^(.-)[^/|]*$" .. (path:match "^%./(.+)$" or path))
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
        setting     = fx.setting,
        vs          = stage_filename "vs",
        fs          = stage_filename "fs",
        cs          = stage_filename "cs",
        depth       = stage_filename "depth",
        di          = stage_filename "di",
        varyings    = fx.varyings,
        depth_varyings=fx.depth and fx.depth.varyings or nil,
        di_varyings = fx.di and fx.di.varyings or nil,
    }
end

local function create_fx(cfg)
    return is_compute_material(cfg) and
        createComputeProgram(cfg) or
        createRenderProgram(cfg)
end

local function is_uniform_obj(t)
    return nil ~= ('ut'):match(t)
end

local function update_uniforms_handle(attrib, uniforms, filename)
    for n, v in pairs(attrib) do
        if is_uniform_obj(v.type) then
            v.handle = assert(uniforms[n]).handle
        end
        local tex = v.texture or v.image
        if tex then
            local texturename = absolute_path(tex, filename)
            local sampler = v.sampler or "SAMPLER2D"
            v.value = S.texture_create_fast(texturename, sampler)
        end
    end
end

local function material_create(filename)
    local material  = serialize.parse(filename, aio.readall(filename .. "|source.ant"))
    local attribute = serialize.parse(filename, aio.readall(filename .. "|attribute.ant"))
    local fxcfg = build_fxcfg(filename, assert(material.fx, "Invalid material"))
    material.fx = create_fx(fxcfg)
    update_uniforms_handle(attribute.attribs, material.fx.uniforms, filename)

    if attribute.depth then
        update_uniforms_handle(attribute.depth.attribs, material.fx.depth.uniforms, filename)
    end

    if attribute.di then
        update_uniforms_handle(attribute.attribs, material.fx.uniforms, filename)
    end

    material.fx.prog = from_handle(material.fx.prog)
    if material.fx.depth then
        material.fx.depth.prog = from_handle(material.fx.depth.prog)
    end
    if material.fx.di then
        material.fx.di.prog = from_handle(material.fx.di.prog)
    end
    return material, fxcfg, attribute
end

function S.material_create(filename)
    local material, fxcfg, attribute = material_create(filename)
    local pid = material.fx.prog
    if pid then
        MATERIALS[pid] = {
            filename = filename,
            material = material,
            cfg      = fxcfg,
            attr     = attribute,
            type     = "draw"
        }
    end

    if material.fx.depth then
        local dpid = material.fx.depth.prog
        MATERIALS[dpid] = {
            filename = filename,
            material = material,
            cfg      = fxcfg,
            attr     = attribute,
            type     = "depth"
        }
    end

    if material.fx.di then
        local dpid = material.fx.di.prog
        MATERIALS[dpid] = {
            filename = filename,
            material = material,
            cfg      = fxcfg,
            attr     = attribute,
            type     = "draw_indirect"
        }
    end

    return material, attribute
end

function S.material_mark(pid)
    MATERIAL_MARKED[pid] = true
end

function S.material_unmark(pid)
    MATERIAL_MARKED[pid] = nil
end

local function material_destroy(fx)
    -- why? PM only keep 16 bit data(it's bgfx handle data), but program type in high 16 bit with int32 data, we need to recover the type for handle when destroy
    local function make_prog_handle(h)
        assert(h ~= 0xffff)
        --handle type, see: luabgfx.h:7, with enum BGFX_HANDLE
        local PROG_TYPE<const> = 1
        return (PROG_TYPE<<16)|h
    end

    --DO NOT clean fx.prog to nil
    local h = PM.program_reset(fx.prog)
    if h then
        bgfx.destroy(make_prog_handle(h)) 
    end
end

--the serive call will fully remove this material, both cpu and gpu side
function S.material_destroy(material)
    local pid = material.fx.prog
    assert(MATERIALS[pid])
    MATERIALS[pid] = nil
    material_destroy(material.fx)

    if material.fx.depth then
        local dpid = material.fx.depth.prog
        assert(MATERIALS[dpid])
        MATERIALS[dpid] = nil
        material_destroy(material.fx.depth)
    end

    if material.fx.di then
        local diid = material.fx.di.prog
        assert(MATERIALS[diid])
        MATERIALS[diid] = nil
        material_destroy(material.fx.di)
    end
end

-- local REMOVED_PROGIDS = {}
-- local REQUEST_PROGIDS = {}

function S.material_check()
    local removed = PM.program_remove()
    if removed then
        for _, removeid in ipairs(removed) do
            if nil == MATERIAL_MARKED[removeid] then
                local mi = assert(MATERIALS[removeid])
                local fx = get_fx(mi.material.fx, mi.type)
                log.info(("Remove prog:%d, from file:%s"):format(removeid, mi.filename))
                -- we just destroy bgfx program handle and shader handles, but not remove 'material' from cpu side
                
                material_destroy(fx)
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
                local sub_oldfx = get_fx(mi.material.fx, mi.type)
                local sub_newfx = get_fx(newfx, mi.type)
                PM.program_set(requestid, sub_newfx.prog)
                sub_oldfx.prog = requestid
            else
                log.info(("Can not create prog:%d, it have been fully remove by 'S.material_destroy'"):format(requestid))
            end
        end
    end
end
