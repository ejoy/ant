local ecs = ...
local world = ecs.world
local w = world.w

local lfs = require "filesystem.local"
local image = require "image"
require "bake_mathadapter"

local bgfx      = require "bgfx"
local bake      = require "bake"
local ltask     = require "ltask"
local crypt     = require "crypt"

local imaterial = world:interface "ant.asset|imaterial"
local ibaker    = world:interface "ant.baker|ibaker"

local lightmap_sys = ecs.system "lightmap_system"

function lightmap_sys:init()
    ibaker.init_shading_info()
end

function lightmap_sys:entity_init()
    for e in w:select "INIT lightmap:in" do
        local lm = e.lightmap
        if lm.bake_id == nil then
            lm.bake_id = "radiosity_" .. crypt.uuid()
        end
    end
end

local bake_finish_mb = world:sub{"bake_finish"}
local function gen_name(bakeid, name)
    if name == nil then
        return bakeid
    end
    return name .. bakeid:sub(#bakeid-8, #bakeid)
end

local function default_tex_info(w, h, fmt)
    local bits = image.getBitsPerPixel(fmt)
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

    local filename = lme.lightmap_path / gen_name(lm.bakeid, e.name)

    local ti = default_tex_info(lm.size, lm.size, "RGBA32F")
    local lmdata = lm.data
    local m = bgfx.memory_buffer(lmdata:data(), ti.storageSize, lmdata)
    local c = image.encode_image(ti, m, {type = "dds", format="RGBA8", srgb=false})
    local f = lfs.open(filename, "wb")
    f:write(c)
    f:close()

    local tc = texfile_content:format(filename:string())
    local texfile = filename:replace_extension "texture"
    f = lfs.open(texfile, "w")
    f:write(tc)
    f:close()
    
    lme.lightmap_result[lm.bake_id] = {texture_path = texfile,}
end

function lightmap_sys:data_changed()
    for lme in w:select "lightmapper lightmap_path:in lightmap_result:in" do
        for e in w:select "bake_finish lightmap:in render_object:in render_object_update:out" do
            e.render_object_update = true
            save_lightmap(e, lme)
        end
        w:clear "bake_finish"
    end
end

local function load_new_material(material, fx)
    local s = {BAKING_LIGHTMAP = 1}
    for k, v in pairs(fx.setting) do
        s[k] = v
    end
    s["ENABLE_SHADOW"] = nil
    s["identity"] = nil
    s['shadow_cast'] = 'off'
    s['shadow_receive'] = 'off'
    s['skinning'] = 'UNKNOWN'
    s['bloom'] = 'off'
    return imaterial.load(material, s)
end

local function to_none_cull_state(state)
    local s = bgfx.parse_state(state)
	s.CULL = "NONE"
	return bgfx.make_state(s)
end

function lightmap_sys:end_filter()
    for e in w:select "filter_result:in material:in render_object:in filter_material:out" do
        local fr = e.filter_result
        local le = w:singleton("lightmap_queue", "primitive_filter:in")
        for _, fn in ipairs(le.primitive_filter) do
            if fr[fn] then
                local fm = e.filter_material
                local ro = e.render_object
                local material = e.material
                --TODO: e.material should be string
                material = type(material) == "string" and material or tostring(material)
                local nm = load_new_material(material, ro.fx)
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

local function bake_all()
    local scene_renderobjects = find_scene_render_objects "main_queue"

    local lm_queue = w:singleton("lightmap_queue", "primitive_filter:in")
    for _, fn in ipairs(lm_queue.primitive_filter) do
        for e in w:select (fn .. " mesh:in lightmap:in render_object:in widget_entity:absent name?in bake_finish?out") do
            log.info(("start bake entity: %s"):format(e.name))
            ibaker.bake_entity(e.render_object.worldmat, e.mesh, e.lightmap, scene_renderobjects)
            e.bake_finish = true
            log.info(("end bake entity: %s"):format(e.name))
        end
    end
end

local function _bake(id)
    if id then
        for e in w:select "mesh:in lightmap:in render_object:in" do
            local lm = e.lightmap
            if id == lm.bake_id then
                ibaker.bake_entity(e.render_object.worldmat, e.mesh, lm, find_scene_render_objects "main_queue")
                e.bake_finish = true
                w:sync("bake_finish?out", e)
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

function lightmap_sys:end_frame()
    for msg in bake_mb:each() do
        local id = msg[2]
        ltask.fork(function ()
            local ServiceBgfxMain = ltask.queryservice "bgfx_main"
            ltask.call(ServiceBgfxMain, "pause")
            _bake(id)
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
