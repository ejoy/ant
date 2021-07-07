local ecs = ...
local world = ecs.world
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

local ipf       = world:interface "ant.scene|iprimitive_filter"
local irender   = world:interface "ant.render|irender"
local imaterial = world:interface "ant.asset|imaterial"
local icp       = world:interface "ant.render|icull_primitive"
local itimer    = world:interface "ant.timer|itimer"
local ientity   = world:interface "ant.render|entity"

local lm_trans = ecs.transform "lightmap_transform"
function lm_trans.process_entity(e)
    e._lightmap = {}
end

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
    if sb.storage_rb == nil then
        local flags = sampler.sampler_flag{
            MIN="POINT",
            MAG="POINT",
            U="CLAMP",
            V="CLAMP",
            BLIT="BLIT_READWRITE",
        }
        sb.storage_rb = fbmgr.create_rb{w=size, h=size, layers = 1, format="RGBA32F", flags=flags}
    end

    return sb.storage_rb
end

local function default_weight()
    return 1.0
end

local function create_hemisphere_weights_texture(hemisize, weight_func)
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

    local flags = sampler.sampler_flag {
        MIN="POINT",
        MAG="POINT",
        U="CLAMP",
        V="CLAMP",
    }
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
    local m = ientity.create_mesh{"p1", {0, 0, 0, 0}}   --shader will not use the vertex data, use gl_VertexID
    return {
        weight_ds_eid = ientity.create_simple_render_entity("lightmap_weight_downsample", 
                            "/pkg/ant.bake/materials/weight_downsample.material", m, nil, 0),
        ds_eid = ientity.create_simple_render_entity("lightmap_downsample", 
                            "/pkg/ant.bake/materials/downsample.material", m, nil, 0)
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
    for ii=0, downsample_viewid_count-1 do
        local vid = lightmap_viewid+ii
        local idx = ii % 2
        fbmgr.bind(vid, fb[idx+1])
        if vid == lightmap_viewid then
            bgfx.set_view_rect(vid, 0, 0, bake_fbw, bake_fbh)
        else
            bgfx.set_view_rect(vid, 0, 0, hsize, hsize)
            hsize = hsize / 2
        end
    end

    return {
        fb = fb,
        downsample = create_downsample(),
    }
end

function lightmap_sys:init()
    shading_info = init_shading_info()

    world:create_entity {
        policy = {
            "ant.bake|lightmap_baker",
            "ant.general|name",
        },
        data = {
            primitive_filter = {
                filter_type = "lightmap",
            },
            lightmap_baker = {},
        }
    }

    world:create_entity {
        policy = {
            "ant.bake|scene_watcher",
            "ant.general|name",
        },
        data = {
            primitive_filter = {
                filter_type = "visible",
            },
            scene_watcher = {},
        }
    }
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

local function draw_scene(pf)
    for _, result in ipf.iter_filter(pf) do
        for _, item in ipf.iter_target(result) do
            irender.draw(lightmap_viewid, item)
        end
    end
end

local ilm = ecs.interface "ilightmap"

local function create_context_setting(lm)
    return {
        size = lm.size,
        z_near = 0.001, z_far = 100,
        interp_pass_count = 2, interp_threshold = 0.001,
        cam2surf_dis_modifier = 0.0,
    }
end

local function update_bake_shading(lm)
    local lmsize = lm.size

    shading_info.storage_rb = fbmgr.get_rb(get_storage_buffer(lmsize)).handle
    shading_info.weight_tex = {stage=1, texture = {handle=get_weight_texture(lmsize)}}
end

local function read_tex(hemix, hemiy, srctex)
    local function get_image_memory(tex, w, h, elemsize)
        local m = bgfx.memory_buffer(w*h*elemsize)
        local whichframe = bgfx.read_texture(tex, m)
        while bgfx.frame() < whichframe do end
        return m
    end

    local function create_tex(w, h, fmt)
        fmt = fmt or "RGBA32F"
        local flags = sampler.sampler_flag{
                MIN="POINT",
                MAG="POINT",
                U="CLAMP",
                V="CLAMP",
                BLIT="BLIT_READWRITE",
        }
        return bgfx.create_texture2d(w, h, false, 1, fmt, flags)
    end

    local function copy_tex(viewid, dsttex, srctex, w, h)
        bgfx.blit(viewid,
        dsttex, 0, 0,
        srctex, 0, 0, w, h)
    end

    local function save_bin(filename, mm, w, h, numelem)
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

    local tt = create_tex(hemix, hemiy, "RGBA32F")
    copy_tex(lightmap_storage_viewid+1, tt, srctex, hemix, hemiy)
    local mm = get_image_memory(tt, hemix, hemiy, 16)
    bake.save_tga("d:/tmp/aa.tga", mm, hemix, hemiy, 4);
    save_bin("d:/tmp/t.bin", mm, hemix, hemiy, 4)
end

local skycolor = 0xffffffff

function ilm.bake_entity(eid, pf, notcull)
    local e = world[eid]
    if e == nil then
        return log.warn(("invalid entity:%d"):format(eid))
    end

    if e._lightmap == nil then
        return log.warn(("entity %s not set any lightmap info will not be baked"):format(e.name or ""))
    end

    local lm = e.lightmap
    local s = create_context_setting(lm)
    local bake_ctx = bake.create_lightmap_context(s)

    update_bake_shading(lm)

    local li = {width=lm.size, height=lm.size, channels=4}
    log.info(("[%d-%s] lightmap:w=%d, h=%d, channels=%d"):format(eid, e.name or "", li.width, li.height, li.channels))
    e._lightmap.data = bake_ctx:set_target_lightmap(li)

    local g = load_geometry_info(e._rendercache)
    bake_ctx:set_geometry(g)
    log.info(("[%d-%s] bake: begin"):format(eid, e.name or ""))

    local c = itimer.fetch_time()
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
            if nil == notcull then
                icp.cull(pf, math3d.mul(proj, view))
            end
            draw_scene(pf)
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

            local hemix, hemiy = bake.hemi_count(size)
            local dsttex = shading_info.fb.render_textures[write].texture.handle
            bgfx.blit(lightmap_storage_viewid,
                shading_info.storage_rb, writex, writey,
                dsttex, 0, 0, hemix, hemiy)
            bgfx.frame()
        end,
        read_lightmap = function(size)
            local m = bgfx.memory_buffer(size)
            local readend = bgfx.read_texture(shading_info.storage_rb, m)
            while (bgfx.frame() < readend) do end
            return m
        end,
        process = function(p)
            local ec = itimer.fetch_time()
            if ec - c >= 1000 then
                c = ec
                log.info(("[%d-%s] process:%2f"):format(eid, e.name or "", p))
            end
        end
    }

    bake_ctx:bake(cb)

    log.info(("[%d-%s] bake: end"):format(eid, e.name or ""))

    e._lightmap.data:postprocess()
    e._lightmap.data:save "d:/work/ant/tools/lightmap_baker/lm.tga"
    log.info(("[%d-%s] postprocess: finish"):format(eid, e.name or ""))
end

local function bake_all()
    local lm_e = world:singleton_entity "lightmap_baker"
    local se = world:singleton_entity "scene_watcher"
    for _, result in ipf.iter_filter(lm_e.primitive_filter) do
        for _, item in ipf.iter_target(result) do
            ilm.bake_entity(item.eid, se.primitive_filter)
        end
    end
end

local bake_mb = world:sub{"bake"}
function lightmap_sys:end_frame()
    for msg in bake_mb:each() do
        local eid = msg[2]
        if eid then
            local se = world:singleton_entity "scene_watcher"
            ilm.bake_entity(eid, se.primitive_filter)
        else
            log.info("bake entity scene with lightmap setting")
            bake_all()
        end
    end
end

