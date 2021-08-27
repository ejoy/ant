local ecs = ...
local world = ecs.world
local w = world.w

local lfs = require "filesystem.local"
local fs = require "filesystem"
local image = require "image"
require "bake_mathadapter"

local bgfx      = require "bgfx"
local bake      = require "bake"
local ltask     = require "ltask"
local crypt     = require "crypt"

local assetmgr  = import_package "ant.asset"

local imaterial = world:interface "ant.asset|imaterial"
local ibaker    = world:interface "ant.bake|ibaker"

local bake_lm_sys = ecs.system "bake_lightmap_system"
local bake_fx<const> = {
    vs = "/pkg/ant.bake/materials/shaders/vs_pbr_baked.sc",
    fs = "/pkg/ant.bake/materials/shaders/fs_pbr_baked.sc",
}

function bake_lm_sys:init()
    ibaker.init()
end

function bake_lm_sys:init_world()
    ibaker.init_framebuffer()
end

function bake_lm_sys:entity_init()
    for e in w:select "INIT lightmap:in" do
        local lm = e.lightmap
        if lm.bake_id == nil then
            lm.bake_id = "radiosity_" .. crypt.uuid()
        end
    end
end

local bake_finish_mb = world:sub{"bake_finish"}
local function gen_name(bakeid, name)
    local n = name and name .. bakeid:sub(#bakeid-8, #bakeid) or bakeid
    return n .. ".dds"
end

local function default_tex_info(w, h, fmt)
    local bits = image.get_bits_pre_pixel(fmt)
    local s = (bits//8) * w * h
    return {
        width=w, height=h, format=fmt,
        numLayers=1, numMips=1, storageSize=s,
        bitsPerPixel=bits,
        depth=1, cubeMap=false,
    }
end

local texfile_content<const> = [[
normalmap: false
path: %s
sRGB: true
compress:
    android: ASTC6x6
    ios: ASTC6x6
    windows: BC3
sampler:
    MAG: LINEAR
    MIN: LINEAR
    U: CLAMP
    V: CLAMP
]]

local function save_lightmap(e, lme)
    local lm = e.lightmap

    local local_lmpath = lme.lightmap_path:localpath()
    local name = gen_name(lm.bake_id, e.name)
    local filename = lme.lightmap_path / name
    assert(not fs.exists(filename))
    local local_filename = local_lmpath / name
    local ti = default_tex_info(lm.size, lm.size, "RGBA32F")
    local lmdata = lm.data
    local m = bgfx.memory_buffer(lmdata:data(), ti.storageSize, lmdata)
    local c = image.encode_image(ti, m, {type = "dds", format="RGBA8", srgb=false})
    local f = lfs.open(local_filename, "wb")
    f:write(c)
    f:close()

    local tc = texfile_content:format(filename:string())
    local texfile = filename:replace_extension "texture"
    local local_texfile = local_lmpath / texfile:filename():string()
    f = lfs.open(local_texfile, "w")
    f:write(tc)
    f:close()
    
    lme.lightmap_result[lm.bake_id] = {texture_path = texfile:string(),}
end

local function load_bake_material(ro)
    local s = {BAKING_LIGHTMAP = 1}
    for k, v in pairs(ro.fx.setting) do
        s[k] = v
    end
    s["ENABLE_SHADOW"] = nil
    s["identity"] = nil
    s['shadow_cast'] = nil
    s['shadow_receive'] = nil
    s['skinning'] = nil
    s['bloom'] = nil
    local fx = assetmgr.load_fx(bake_fx, s)
    return {
        fx          = fx,
        properties  = ro.properties,
        state       = ro.state,
        stencil     = ro.stencil,
    }
end

local function to_none_cull_state(state)
    local s = bgfx.parse_state(state)
	s.CULL = "NONE"
	return bgfx.make_state(s)
end

function bake_lm_sys:end_filter()
    for e in w:select "filter_result:in render_object:in filter_material:out" do
        local fr = e.filter_result
        local le = w:singleton("bake_lightmap_queue", "primitive_filter:in")
        for _, fn in ipairs(le.primitive_filter) do
            if fr[fn] then
                local fm = e.filter_material
                local ro = e.render_object
                local nm = load_bake_material(ro)
                fm[fn] = {
                    fx          = nm.fx,
                    properties  = nm.properties,
                    state       = to_none_cull_state(nm.state),
                    stencil     = nm.stencil,
                }
            end
        end
    end
end

local function find_scene_render_objects(queuename)
    local q = w:singleton(queuename, "primitive_filter:in")
    local renderobjects = {}
    for _, fn in ipairs(q.primitive_filter) do
        for e in w:select(fn .. " render_object:in widget_entity:absent") do
            renderobjects[#renderobjects+1] = e.render_object
        end
    end

    return renderobjects
end

local function create_context_setting(hemisize)
    return {
        size = hemisize,
        z_near = 0.001, z_far = 100,
        interp_pass_count = 0, interp_threshold = 0.001,
        cam2surf_dis_modifier = 0.0,
    }
end

local function bake_entity(e, scene_renderobjects, lme)
    log.info(("start bake entity: %s"):format(e.name))
    ibaker.bake_entity(e.render_object.worldmat, e.mesh, e.lightmap, scene_renderobjects)
    save_lightmap(e, lme)
    e.render_object_update = true
    w:sync("render_object_update?out", e)
    log.info(("end bake entity: %s"):format(e.name))
end

local function get_lme()
    local lme = w:singleton("lightmapper", "lightmap_result:in")
    w:sync("lightmap_path:in", lme)
    return lme
end

local function bake_all()
    local scene_renderobjects = find_scene_render_objects "main_queue"

    local lmq = w:singleton("bake_lightmap_queue", "primitive_filter:in")
    local lme = get_lme()
    for _, fn in ipairs(lmq.primitive_filter) do
        for e in w:select (fn .. " mesh:in lightmap:in render_object:in widget_entity:absent name?in") do
            bake_entity(e, scene_renderobjects, lme)
        end
    end
end

local function _bake(id)
    if id then
        for e in w:select "mesh:in lightmap:in render_object:in" do
            if id == e.lightmap.bake_id then
                bake_entity(e, find_scene_render_objects "main_queue", get_lme())
                break
            end
        end
    else
        log.info "bake entity scene with lightmap setting"
        bake_all()
    end

    world:pub{"bake_finish", id}
end

local bake_mb = world:sub{"bake"}

function bake_lm_sys:end_frame()
    for msg in bake_mb:each() do
        local id = msg[2]
        ltask.fork(function ()
            local ServiceBgfxMain = ltask.queryservice "bgfx_main"
            ltask.call(ServiceBgfxMain, "pause")
            bgfx.encoder_begin()
            _bake(id)
            bgfx.encoder_end()
            ltask.call(ServiceBgfxMain, "continue")
        end)
    end
end

------------------------------------------------------------------------
local ilm = ecs.interface "ilightmap"

function ilm.find_sample(lightmap, renderobj, triangleidx)
    local hemisize = lightmap.hemisize

    local s = create_context_setting(hemisize)
    local bake_ctx = bake.create_lightmap_context(s)
    local g = ibaker.load_geometry_info(renderobj)
    bake_ctx:set_geometry(g)
    local lmsize = lightmap.size
    local li = {width=lmsize, height=lmsize, channels=4}
    log.info(("lightmap:w=%d, h=%d, channels=%d"):format(li.width, li.height, li.channels))
    lightmap.data = bake_ctx:set_target_lightmap(li)

    return bake_ctx:find_sample(triangleidx)
end

function ilm.bake_entity(bakeobj, lightmap)
    local scene_renderobjs = find_scene_render_objects "main_queue"
    return ibaker.bake_entity(bakeobj, lightmap, scene_renderobjs)
end
