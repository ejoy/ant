local ecs = ...
local world = ecs.world
local w = world.w
require "bake_mathadapter"

local renderpkg = import_package "ant.render"
local viewidmgr = renderpkg.viewidmgr
local declmgr   = renderpkg.declmgr
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local math3d    = require "math3d"
local bgfx      = require "bgfx"
local bake      = require "bake"
local ltask     = require "ltask"
local crypt     = require "crypt"

local irender   = world:interface "ant.render|irender"
local imaterial = world:interface "ant.asset|imaterial"
local icamera   = world:interface "ant.camera|camera"
local itimer    = world:interface "ant.timer|itimer"
local ientity   = world:interface "ant.render|entity"

local lightmap_sys = ecs.system "lightmap_system"

local shading_info

local downsample_viewid_count<const> = 10 --max 1024x1024->2^10
local lightmap_downsample_viewids = viewidmgr.alloc_viewids(downsample_viewid_count, "lightmap_ds")
local lightmap_viewid<const> = lightmap_downsample_viewids[1]
--check is successive
for idx, viewid in ipairs(lightmap_downsample_viewids) do
    assert(viewid == lightmap_viewid+idx-1)
end
local lightmap_storage_viewid<const> = viewidmgr.generate "lightmap_storage"

local cache_size_buffers = {}
local function get_csb(size)
    local sb = cache_size_buffers[size]
    if sb == nil then
        sb = {}
        cache_size_buffers[size] = sb
    end
    return sb
end

local function get_storage_buffer(size)
    local sb = get_csb(size)
    if sb.storage_rbidx == nil then
        local flags = sampler.sampler_flag{
            MIN="POINT",
            MAG="POINT",
            U="CLAMP",
            V="CLAMP",
            BLIT="BLIT_READWRITE",
        }
        sb.storage_rbidx = fbmgr.create_rb{w=size, h=size, layers = 1, format="RGBA32F", flags=flags}
    end

    return sb.storage_rbidx
end

local function default_weight()
    return 1.0
end

local function gen_hemisphere_weights(hemisize, weight_func)
    weight_func = weight_func or default_weight
    local weights = {}
 	local center = (hemisize - 1) * 0.5
 	local sum = 0;
 	for y = 0, hemisize-1 do
         local dy = 2.0 * (y-center)/hemisize
           for x=0, hemisize-1 do
             local dx = 2.0 * (x-center)/hemisize
             local v = math3d.tovalue(math3d.normalize(math3d.vector(dx, dy, 1.0)))

 			local solidAngle = v[3] * v[3] * v[3]
            
            local w0 = 2 * (y * (3 * hemisize) + x)
            local w1 = w0 + 2 * hemisize
            local w2 = w1 + 2 * hemisize

 			-- center weights
 			weights[w0+1] = solidAngle * weight_func(v[3]);
 			weights[w0+2] = solidAngle
 			-- left/right side weights
 			weights[w1+1] = solidAngle * weight_func(math.abs(v[1]))
 			weights[w1+2] = solidAngle
 			-- up/down side weights
 			weights[w2+1] = solidAngle * weight_func(math.abs(v[1]))
 			weights[w2+2] = solidAngle
 			sum = sum + 3.0 * solidAngle
       end
    end

    local weightScale = 1.0 / sum
    for i=1, #weights do
        weights[i] = weights[i] * weightScale;
    end

    return weights
end

local function create_hemisphere_weights_texture(hemisize, weight_func)
    local weights = gen_hemisphere_weights(hemisize, weight_func)

    local flags = sampler.sampler_flag {
        MIN="POINT",
        MAG="POINT",
        U="CLAMP",
        V="CLAMP",
    }

    
    -- do
    --     local w = {}
    --     for i=1, #weights/2 do
    --         local ridx = (i-1) * 2
    --         local lidx = (i-1) * 3
    --         w[lidx+1]    = weights[ridx+1]
    --         w[lidx+2]    = weights[ridx+2]
    --         w[lidx+3]    = 0.0
    --     end
    --     local mm = bgfx.memory_buffer("fff", w)
    --     bake.save_tga("d:/tmp/weight.tga", mm, 3*hemisize, hemisize, 3)
    -- end
    
    return bgfx.create_texture2d(3*hemisize, hemisize, false, 1, "RG32F", flags, bgfx.memory_buffer("ff", weights))
end

local function get_weight_texture(size)
    local sb = get_csb(size)
    if sb.weight_tex == nil then
        -- weight texture should not depend 'size'
        sb.weight_tex = create_hemisphere_weights_texture(size)
    end

    return sb.weight_tex
end

local function create_downsample()
    return {
        weight_ds_eid = ientity.create_simple_render_entity("lightmap_weight_downsample", 
                            "/pkg/ant.bake/materials/weight_downsample.material", ientity.create_mesh{"p1", {0, 0, 0, 0}}, nil, 0),
        ds_eid = ientity.create_simple_render_entity("lightmap_downsample", 
                            "/pkg/ant.bake/materials/downsample.material", ientity.create_mesh{"p1", {0, 0, 0, 0}}, nil, 0)
    }
end

local bake_fbw, bake_fbh, fb_hemi_unit_size = bake.framebuffer_size()

local function init_shading_info()
    local flags = sampler.sampler_flag{
        MIN="POINT",
        MAG="POINT",
        U="CLAMP",
        V="CLAMP",
        RT="RT_ON",
    }

    local hsize = fb_hemi_unit_size/2
    local fb = {
        fbmgr.create{
            fbmgr.create_rb{w=bake_fbw, h=bake_fbh, layers=1, format="RGBA32F", flags=flags},
            fbmgr.create_rb{w=bake_fbw, h=bake_fbh, layers=1, format="D24S8", flags=flags},
        },
        fbmgr.create{
            fbmgr.create_rb{w=hsize, h=hsize, layers=1, format="RGBA32F", flags=flags},
        }
    }
    local function get_rb(fbidx)
        return fbmgr.get_rb(fbmgr.get(fb[fbidx])[1]).handle
    end

    fb.render_textures = {
        {stage=0, texture={handle=get_rb(1)}},
        {stage=0, texture={handle=get_rb(2)}},
    }
    fbmgr.bind(lightmap_viewid, fb[1])
    bgfx.set_view_rect(lightmap_viewid, 0, 0, bake_fbw, bake_fbh)
    for ii=1, downsample_viewid_count-1 do
        local vid = lightmap_viewid+ii
        local idx = ii % 2
        fbmgr.bind(vid, fb[idx+1])
        bgfx.set_view_rect(vid, 0, 0, hsize, hsize)
        hsize = hsize / 2
    end

    return {
        fb = fb,
        downsample = create_downsample(),
    }
end

local lm_result_eid
local function create_lightmap_result_entity()
    return world:create_entity{
        policy = {
            "ant.bake|lightmap_result",
            "ant.general|name",
        },
        data = {
            name = "lightmap_result",
            lightmap_result = {},
        },
    }
end

local lightmap_queue_surface_types<const> = {
    "foreground", "opaticy", "background",
}
function lightmap_sys:init()
    shading_info = init_shading_info()

    --we will not use this camera
    local camera_ref = icamera.create{
        viewdir = mc.ZAXIS,
        eyepos = mc.ZERO_PT,
        name = "lightmap camera"
    }
    irender.create_view_queue({x=0, y=0, w=1, h=1}, "lightmap_queue", camera_ref, "lightmap", nil, lightmap_queue_surface_types)
    lm_result_eid = create_lightmap_result_entity()
end

function lightmap_sys:entity_init()
    for e in w:select "INIT lightmap:in" do
        local lm = e.lightmap
        if lm.bake_id == nil then
            lm.bake_id = "radiosity_" .. crypt.uuid()
        end
    end
end

local function load_new_material(material, fx)
    local s = {BAKING = 1}
    for k, v in pairs(fx.setting) do
        s[k] = v
    end
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
        local fm = e.filter_material
        local le = w:singleton("lightmap_queue", "filter_names:in")
        local ro = e.render_object
        local material = e.material
        material = material._data and tostring(material) or material
        for _, fn in ipairs(le.filter_names) do
            if fr[fn] then
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

local function load_geometry_info(item)
    local e = world[item.eid]
    if item.simple_mesh then
        local p, n, t, vc, i, ic = bake.read_obj(item.simple_mesh)
        return {
            worldmat= math3d.value_ptr(item.worldmat),
            num     = math.tointeger(ic),
            pos     = {
                offset = 0,
                stride = 12,
                memory = p,
                type   = "f",
                native = true,
            },
            normal  = {
                offset = 0,
                stride = 12,
                memory = n,
                type   = "",
                native = true,
            },
            uv      = {
                offset = 0,
                stride = 8,
                memory = t,
                type   = "f",
                native = true,
            },
            index   = {
                offset = 0,
                stride = 2,
                memory = i,
                type   = "H",
                native = true,
            },
        }
    end
    local m = e.mesh
    local function get_type(t)
        local types<const> = {
            u = "B", i = "I", f = "f",
        }

        local tt = types[t]
        assert(tt, "invalid type")
        return types[tt]
    end
    local function get_attrib_item(name)
        for _, vb in ipairs(m.vb) do
            local offset = 0
            local declname = vb.declname
            local stride = declmgr.layout_stride(declname)
            for d in declname:gmatch "%w+" do
                if d:sub(1, 3):match(name) then
                    return {
                        offset = offset,
                        stride = stride,
                        memory = bgfx.memory_buffer(table.unpack(vb.memory)),
                        type   = get_type(d:sub(6, 6)),
                    }
                end
                offset = offset + declmgr.elem_size(d)
            end
        end

        --error(("not found attrib name:%s"):format(name))
    end

    local ib = m.ib
    local index
    if ib then
        local function is_uint32(f)
            if f then
                return f:match "d"
            end
        end
        local t<const> = is_uint32(ib.flag) and "I" or "H"
        index = {
            offset = 0,
            stride = t == "I" and 4 or 2,
            memory = bgfx.memory_buffer(table.unpack(ib.memory)),
            type = t,
        }
    end

    return {
        worldmat= math3d.value_ptr(item.worldmat),
        num     = math.tointeger(m.ib.num),
        pos     = get_attrib_item "p",
        normal  = get_attrib_item "n",
        uv      = get_attrib_item "t21" or get_attrib_item "t20",
        index   = index,
    }
end

local function find_bake_obj(eid)
    for e in w:select "eid:in render_object:in lightmap:in" do
        if e.eid == eid then
            return e.render_object, e.lightmap
        end
    end
end

local function find_scene_render_objects(queuename)
    local q = w:singleton(queuename, "filter_names:in")
    local renderobjects = {}
    for _, fn in ipairs(q.filter_names) do
        for e in w:select(fn .. " render_object:in widget_entity:absent") do
            renderobjects[#renderobjects+1] = e.render_object
        end
    end

    return renderobjects
end

local function draw_scene(renderobjs)
    for _, ro in ipairs(renderobjs) do
        irender.draw(lightmap_viewid, ro)
    end
end

local function create_context_setting(hemisize)
    return {
        size = hemisize,
        z_near = 0.001, z_far = 100,
        interp_pass_count = 0, interp_threshold = 0.001,
        cam2surf_dis_modifier = 0.0,
    }
end

local function update_bake_shading(hemisize, lightmapsize)
    local hemix, hemiy = bake.hemi_count(hemisize)
    assert(hemix == hemiy)
    local s = math.max(hemix, lightmapsize)
    shading_info.storage_rbidx = get_storage_buffer(s)
    shading_info.weight_tex = {stage=1, texture = {handle=get_weight_texture(hemisize)}}
end

local tex_reader = {
    get_image_memory = function (tex, w, h, elemsize)
        local m = bgfx.memory_buffer(w*h*elemsize)
        local whichframe = bgfx.read_texture(tex, m)
        while bgfx.frame() < whichframe do end
        return m
    end,

    create_tex = function (w, h, fmt)
        fmt = fmt or "RGBA32F"
        local flags = sampler.sampler_flag{
                MIN="POINT",
                MAG="POINT",
                U="CLAMP",
                V="CLAMP",
                BLIT="BLIT_READWRITE",
        }
        return bgfx.create_texture2d(w, h, false, 1, fmt, flags)
    end,
    copy_tex = function (viewid, dsttex, srctex, w, h)
        bgfx.blit(viewid,
        dsttex, 0, 0,
        srctex, 0, 0, w, h)
    end,
    save_bin = function (filename, mm, w, h, numelem)
        local header = ("III"):pack(w, h, numelem)
        local f = io.open(filename, "wb")
        f:write(header)
        f:write(tostring(mm))
        f:close()
    end,

    save_bytes = function (filename, mm, w, h, numelem)
        local ss = tostring(mm)
        local t = {}
        for jj=0, h-1 do
            for ii=0, w-1 do
                local idx = jj*w*numelem+ii
                local fmt = ("f"):rep(numelem)
                local tt = table.pack(fmt:unpack(ss:sub(idx, idx+16)))
                for ee=1, numelem do
                    t[#t+1] = ("%2f "):format(tt[ee])
                end
            end
            t[#t+1] = "\n"
        end

        local cc = table.concat(t, "")
        local f = io.open(filename, "w")
        f:write(cc)
        f:close()
    end
}

local function read_tex(hemix, hemiy, srctex, fn, fn_bin)
    local tt = tex_reader.create_tex(hemix, hemiy, "RGBA32F")
    tex_reader.copy_tex(lightmap_storage_viewid+1, tt, srctex, hemix, hemiy)
    local mm = tex_reader.get_image_memory(tt, hemix, hemiy, 16)
    fn = fn or "d:/tmp/aa.tga"
    bake.save_tga(fn, mm, hemix, hemiy, 4)
    
    if fn_bin then
        tex_reader.save_bin(fn_bin, mm, hemix, hemiy, 4)
    end
end

local skycolor = 0xffffffff


local function bake_entity(lightmap, bakeobj, scene_objects)
    local hemisize = lightmap.hemisize
    
    local s = create_context_setting(hemisize)
    local bake_ctx = bake.create_lightmap_context(s)
    local hemix, hemiy = bake_ctx:hemi_count()
    local lmsize = lightmap.size
    update_bake_shading(hemisize, lmsize)
    local li = {width=lmsize, height=lmsize, channels=4}
    log.info(("lightmap:w=%d, h=%d, channels=%d"):format(li.width, li.height, li.channels))
    lightmap.data = bake_ctx:set_target_lightmap(li)

    local g = load_geometry_info(bakeobj)
    bake_ctx:set_geometry(g)
    log.info "bake: begin"

    local c = itimer.fetch_time()
    --TODO: we should move all bake logic code in lua, and put all rasterizier code in c
    local cb = {
        init_buffer = function ()
            bgfx.set_view_clear(lightmap_viewid, "CD", skycolor, 1.0)
            bgfx.set_view_rect(lightmap_viewid, 0, 0, bake_fbw, bake_fbh)
            bgfx.touch(lightmap_viewid)
            bgfx.frame()    --wait for clear, avoid some draw call push in lightmap_viewid queue

            --we will change view rect many time before next clear needed
            --will not clear after another view rect is applied
            bgfx.set_view_clear(lightmap_viewid, "")
        end,
        render_scene = function (vp, view, proj)
            bgfx.set_view_rect(lightmap_viewid, vp[1], vp[2], vp[3], vp[4])
            bgfx.set_view_transform(lightmap_viewid, view, proj)
            draw_scene(scene_objects)
            bgfx.frame()
        end,
        downsample = function(size, writex, writey)
            local hsize = size/2
            local viewid = lightmap_viewid + 1
            local ds = shading_info.downsample

            world[ds.weight_ds_eid]._rendercache.worldmat = mc.IDENTITY_MAT
            world[ds.ds_eid]._rendercache.worldmat = mc.IDENTITY_MAT

            local read, write = 1, 2
            imaterial.set_property(ds.weight_ds_eid, "hemispheres", shading_info.fb.render_textures[read])
            imaterial.set_property(ds.weight_ds_eid, "weights", shading_info.weight_tex)
            irender.draw(viewid, world[ds.weight_ds_eid]._rendercache)

            while hsize > 1 do
                viewid = viewid + 1
                assert(viewid < lightmap_viewid+downsample_viewid_count, 
                    ("lightmap size too large:%d, count:%d"):format(size, downsample_viewid_count))

                read, write = write, read
                imaterial.set_property(ds.ds_eid, "hemispheres", shading_info.fb.render_textures[read])
                
                irender.draw(viewid, world[ds.ds_eid]._rendercache)
                hsize = hsize/2
            end

            local dsttex = shading_info.fb.render_textures[write].texture.handle
            local storagerb = fbmgr.get_rb(shading_info.storage_rbidx)
            bgfx.blit(lightmap_storage_viewid,
                storagerb.handle, writex, writey,
                dsttex, 0, 0, hemix, hemiy)
            bgfx.frame()
        end,
        read_lightmap = function(size)
            local storagerb = fbmgr.get_rb(shading_info.storage_rbidx)
            assert(storagerb.w * storagerb.h * 16 == size) --16 for RGBA32F
            local m = bgfx.memory_buffer(size)
            local readend = bgfx.read_texture(storagerb.handle, m)
            while (bgfx.frame() < readend) do end
            return m
        end,
        process = function(p)
            local ec = itimer.fetch_time()
            if ec - c >= 1000 then
                c = ec
                log.info(("process:%2f"):format(p))
            end
        end
    }

    bake_ctx:bake(cb)

    lightmap.data:postprocess()
    log.info "postprocess: finish"
end

local function bake_all()
    local scene_renderobjects = find_scene_render_objects "main_queue"

    local lm_queue = w:singleton("lightmap_queue", "filter_names:in")
    for _, fn in ipairs(lm_queue.filter_names) do
        for le in w:select (fn .. " render_object:in lightmap:in widget_entity:absent name?in") do
            log.info(("start bake entity: %s"):format(le.name))
            bake_entity(le.render_object, le.lightmap, scene_renderobjects)
            log.info(("end bake entity: %s"):format(le.name))
        end
    end
end

local function _bake(id)
    if id then
        local bakeobj, lightmap = find_bake_obj(id)
        bake_entity(bakeobj, lightmap, find_scene_render_objects "main_queue")
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
    local g = load_geometry_info(renderobj)
    bake_ctx:set_geometry(g)
    local lmsize = lightmap.size
    local li = {width=lmsize, height=lmsize, channels=4}
    log.info(("lightmap:w=%d, h=%d, channels=%d"):format(li.width, li.height, li.channels))
    lightmap.data = bake_ctx:set_target_lightmap(li)

    return bake_ctx:find_sample(triangleidx)
end


function ilm.bake_entity(bakeobj, lightmap)
    local scene_renderobjs = find_scene_render_objects "main_queue"
    return bake_entity(lightmap, bakeobj, scene_renderobjs)
end

ilm.find_bake_obj = find_bake_obj

function ilm.bake_from_eid(eid)
    local bakeobj, lightmap = find_bake_obj(eid)
    return ilm.bake_entity(bakeobj, lightmap)
end
