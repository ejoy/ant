local ecs = ...
local world = ecs.world
local w         = world.w

local ibaker    = ecs.interface "ibaker"

local bake      = require "bake"
local bgfx      = require "bgfx"
local math3d    =   require "math3d"

local renderpkg = import_package "ant.render"
local sampler   = renderpkg.sampler
local declmgr   = renderpkg.declmgr
local fbmgr     = renderpkg.fbmgr
local viewidmgr = renderpkg.viewidmgr

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.uitl

local ientity   = ecs.import.interface "ant.render|ientity"
local irender   = ecs.import.interface "ant.render|irender"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local icamera   = ecs.import.interface "ant.camera|icamera"
local ics       = ecs.import.interface "ant.render|icluster_render"
local isp       = ecs.import.interface "ant.render|isystem_properties"

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local bake_fbw, bake_fbh, fb_hemi_unit_size = bake.framebuffer_size()
local fb_hemi_half_size<const> = fb_hemi_unit_size/2

local downsample_viewid_count<const> = 10 --max 1024x1024->2^10
local lightmap_viewid<const> = viewidmgr.get "lightmap_ds"
viewidmgr.check_range("lightmap_ds", downsample_viewid_count)
local lightmap_storage_viewid<const> = viewidmgr.get "lightmap_storage"

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

local hemisize = 64

local setting = {
    size = hemisize,
    z_near = 0.001, z_far = 100,
    interp_pass_count = 0, interp_threshold = 0.001,
    cam2surf_dis_modifier = 0.0,
}

local function create_hemisphere_weights_texture(weight_func)
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

local rb_flags = sampler.sampler_flag{
    MIN="POINT",
    MAG="POINT",
    U="CLAMP",
    V="CLAMP",
    RT="RT_ON",
}

local function create_downsample()
    local function create_ds(tag, material)
        w:register {name = tag}
        ecs.create_entity {
            policy = {
                "ant.render|render",
                "ant.general|name",
            },
            data = {
                name = "tag",
                mesh = ientity.create_mesh{"p1", {0, 0, 0, 0}},
                material = material,
                scene = {
                    srt = mu.srt_obj(),
                },
                filter_state = "",  --force not include to any render queue
                [tag] = true,
            }
        }
    end

    create_ds("weight_ds", "/pkg/ant.bake/materials/weight_downsample.material")
    create_ds("simple_ds", "/pkg/ant.bake/materials/downsample.material")
end

local function frame()
    bgfx.encoder_end()
    local fidx = bgfx.frame()
    bgfx.encoder_begin()
    return fidx
end

local function get_image_memory(tex, w, h, elemsize)
    local size = w * h * elemsize
    local m = bgfx.memory_buffer(size)
    local readend = bgfx.read_texture(tex, m)
    while frame() < readend do end
    return m
end

local tex_reader = {
    get_image_memory = get_image_memory, 
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
                local sampleidx = jj*w*numelem+ii
                local fmt = ("f"):rep(numelem)
                local tt = table.pack(fmt:unpack(ss:sub(sampleidx, sampleidx+16)))
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

local downsampler = {}
function downsampler:init()
    self.weight_tex  = {stage=1, texture={handle=create_hemisphere_weights_texture()}}
    create_downsample()
end

function downsampler:update(fbs)
    local function gen_rb_tex(fbidx)
        local handle = fbmgr.get_rb(fbmgr.get(fbidx)[1]).handle
        return {stage=0, texture={handle = handle}}
    end

    self.render_textures = {
        gen_rb_tex(fbs[1]),
        gen_rb_tex(fbs[2]),
    }

    local hsize = fb_hemi_half_size
    fbmgr.bind(lightmap_viewid, fbs[1])
    bgfx.set_view_rect(lightmap_viewid, 0, 0, bake_fbw, bake_fbh)
    for ii=1, downsample_viewid_count-1 do
        local vid = lightmap_viewid+ii
        local sampleidx = ii % 2
        fbmgr.bind(vid, fbs[sampleidx+1])
        bgfx.set_view_rect(vid, 0, 0, hsize, hsize)
        hsize = hsize / 2
    end
end

function downsampler:downsample(hemisize)
    local hsize = hemisize//2
    local viewid = lightmap_viewid + 1
    
    local we = w:singleton("weight_ds", "render_object:in")
    local se = w:singleton("simple_ds", "render_object:in")
    local we_obj, se_obj = we.render_object, se.render_object

    local read, write = 1, 2
    imaterial.set_property_directly(we_obj.properties, "hemispheres",    self.render_textures[read])
    imaterial.set_property_directly(we_obj.properties, "weights",        self.weight_tex)
    irender.draw(viewid, we_obj)

    while hsize > 1 do
        viewid = viewid + 1
        assert(viewid < (lightmap_viewid+downsample_viewid_count),
            ("lightmap size too large:%d, count:%d"):format(fb_hemi_half_size, downsample_viewid_count))

        read, write = write, read
        imaterial.set_property_directly(se_obj.properties, "hemispheres", self.render_textures[read])

        irender.draw(viewid, se_obj)
        hsize = hsize/2
    end

    return self.render_textures[write].texture.handle
end

local function create_lightmap_queue()
    local camera_ref_WONT_USED = icamera.create{
        viewdir = mc.ZAXIS,
        eyepos = mc.ZERO_PT,
        updir = mc.YAXIS,
        name = "lightmap camera"
    }

    local fbidx = fbmgr.create{
        fbmgr.create_rb{w=bake_fbw, h=bake_fbh, layers=1, format="RGBA32F", flags=rb_flags},
        fbmgr.create_rb{w=bake_fbw, h=bake_fbh, layers=1, format="D24S8", flags=rb_flags},
    }

    ecs.create_entity {
        policy = {
            "ant.render|render_queue",
            "ant.render|cull",
            "ant.general|name",
        },
        data = {
            primitive_filter = {
                filter_type = "lightmap",
                "foreground", "opacity", "background",
            },
            camera_ref = camera_ref_WONT_USED,
            render_target = {
                view_rect = {x=0, y=0, w=bake_fbw, h=bake_fbh},
                viewid = lightmap_viewid,
                view_mode = "s",
                clear_state = {
                    color = 0x000000ff,
                    depth = 1.0,
                    clear = "CD",
                },
                fb_idx = fbidx,
            },
            name = "bake_lightmap_queue",
            bake_lightmap_queue = true,
            visible = true,
            INIT = true,
            queue_name = "bake_lightmap_queue",
            cull_tag = {},
        }
    }
end

local function load_geometry_info(worldmat, mesh)
    -- if item.simple_mesh then
    --     local p, n, t, vc, i, ic = bake.read_obj(item.simple_mesh)
    --     return {
    --         worldmat= math3d.value_ptr(item.worldmat),
    --         num     = math.tointeger(ic),
    --         pos     = {
    --             offset = 0,
    --             stride = 12,
    --             memory = p,
    --             type   = "f",
    --             native = true,
    --         },
    --         normal  = {
    --             offset = 0,
    --             stride = 12,
    --             memory = n,
    --             type   = "",
    --             native = true,
    --         },
    --         uv      = {
    --             offset = 0,
    --             stride = 8,
    --             memory = t,
    --             type   = "f",
    --             native = true,
    --         },
    --         index   = {
    --             offset = 0,
    --             stride = 2,
    --             memory = i,
    --             type   = "H",
    --             native = true,
    --         },
    --     }
    -- end
    local function get_type(t)
        local types<const> = {
            u = "B", i = "I", f = "f",
        }

        local tt = types[t]
        assert(tt, "invalid type")
        return types[tt]
    end
    local function get_attrib_item(name)
        for _, vb in ipairs(mesh.vb) do
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

        error(("not found attrib name:%s"):format(name))
    end

    local ib = mesh.ib
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
        worldmat= math3d.value_ptr(worldmat),
        num     = math.tointeger(mesh.ib.num),
        pos     = get_attrib_item "p",
        normal  = get_attrib_item "n",
        uv0     = get_attrib_item "t20",
        uv1     = get_attrib_item "t21",
        index   = index,
    }
end

ibaker.load_geometry_info = load_geometry_info

local skycolor = 0xffffffff

local function init_buffer()
    bgfx.set_view_clear(lightmap_viewid, "CD", skycolor, 1.0)
    bgfx.set_view_rect(lightmap_viewid, 0, 0, bake_fbw, bake_fbh)
    bgfx.touch(lightmap_viewid)
    frame()
    bgfx.set_view_clear(lightmap_viewid, "")
end

local function render_scene(vp, view, proj, sceneobjs)
    bgfx.touch(lightmap_viewid)
    bgfx.set_view_rect(lightmap_viewid, vp[1], vp[2], vp[3], vp[4])
    bgfx.set_view_transform(lightmap_viewid, view, proj)
    local vr = {x=vp[1], y=vp[2], w=vp[3], h=vp[4]}
    local camerapos = math3d.vector(view[4], view[8], view[12], 1.0)
    isp.update_lighting_properties(vr, camerapos, setting.z_near, setting.z_far)
    ics.build_cluster_aabbs(lightmap_viewid)
    ics.cull_lights(lightmap_viewid)
    for _, ro in ipairs(sceneobjs) do
        irender.draw(lightmap_viewid, ro)
    end
    frame()
end

local storage = {
    blit_fbidx = fbmgr.create{
        fbmgr.create_rb{w=fb_hemi_half_size, h=fb_hemi_half_size, layers=1, format="RGBA32F", flags=rb_flags}
    },
}

storage.__index = storage
local storage_flags<const> = sampler.sampler_flag{
    MIN="POINT",
    MAG="POINT",
    U="CLAMP",
    V="CLAMP",
    BLIT="BLIT_READWRITE",
}

function storage.new(hemix, hemiy, lm_w, lm_h)
    local nx, ny = math.ceil(lm_w / hemix), math.ceil(lm_h / hemiy)
    local w, h = nx * hemix, ny * hemiy

    return setmetatable({
        index = 0,
        nx = nx, ny = ny,
        w = w, h = h,
        hemix = hemix, hemiy = hemiy,
        storage_rbidx = fbmgr.create_rb{w=w, h=h, layers = 1, format="RGBA32F", flags=storage_flags}
    }, storage)
end

function storage:position()
    local idx = self.index
    assert(self.index < (self.nx*self.ny))
    return  (idx %  self.nx) * self.hemix,
            (idx // self.nx) * self.hemiy
end

function storage:is_full()
    return self.index >= (self.nx*self.ny)
end

function storage:next()
    self.index = self.index + 1
    return self:is_full()
end

function storage:copy2storage(tex)
    local storagerb = fbmgr.get_rb(self.storage_rbidx)
    local wx, wy = self:position()
    assert(wx < self.w and wy < self.h)
    bgfx.blit(lightmap_storage_viewid,
        storagerb.handle, wx, wy,
        tex, 0, 0, self.hemix, self.hemiy)
    frame()

    self:next()
end

function storage:read_memory()
    local storagerb = fbmgr.get_rb(self.storage_rbidx)
    return get_image_memory(storagerb.handle, self.w, self.h, 16)
end

local hemisphere_batcher = {}; hemisphere_batcher.__index = hemisphere_batcher

function hemisphere_batcher.new(bake_ctx, hemisize, hemix, hemiy, lm)
    return setmetatable(
        {
            bake_ctx = bake_ctx,
            hemisize = hemisize,
            hemix = hemix,
            hemiy = hemiy,
            lightmap = lm,
            index = 0,
            count = hemix * hemiy,
            storage = storage.new(hemix, hemiy, lm.size, lm.size)
        }, hemisphere_batcher)
end

function hemisphere_batcher:hemi_pos(index)
    return 
        (index % self.hemix) * self.hemisize * 3,
        (index //self.hemix) * self.hemisize
end

function hemisphere_batcher:step()
    local index = self.index

    if index == self.count then
        self:integrate()
        index = 0
    end

    if index == 0 then
        init_buffer()
    end

    local x, y = self:hemi_pos(index)
    self.index = index + 1
    return x, y
end

function hemisphere_batcher:write2lightmap(bake_ctx)
    local m = self.storage:read_memory()
    bake_ctx:write2lightmap(m, self.lightmap.data, self.hemix, self.hemiy, self.storage.nx, self.storage.ny)
end

function hemisphere_batcher:integrate()
    self.storage:copy2storage(downsampler:downsample(self.hemisize))
end

function ibaker.init()
    create_lightmap_queue()
    downsampler:init()

end

function ibaker.init_framebuffer()
    local le = w:singleton("bake_lightmap_queue", "render_target:in")
    downsampler:update{le.render_target.fb_idx, storage.blit_fbidx}
end

function ibaker.bake_entity(worldmat, bakeobj_mesh, lightmap, scene_objects)
    local s = setting
    local bake_ctx = bake.create_lightmap_context(s)
    local hemix, hemiy = bake_ctx:hemi_count()
    local lmsize = lightmap.size
    local li = {width=lmsize, height=lmsize, channels=4}
    log.info(("lightmap:w=%d, h=%d, channels=%d"):format(li.width, li.height, li.channels))
    lightmap.data = bake_ctx:set_target_lightmap(li)

    local g = load_geometry_info(worldmat, bakeobj_mesh)
    bake_ctx:set_geometry(g)
    log.info "bake: begin"
    local passcount = bake_ctx:pass_count()
    for pass=1, passcount do
        local batcher = hemisphere_batcher.new(bake_ctx, hemisize, hemix, hemiy, lightmap)
        local numsample = bake_ctx:fetch_samples(pass)
        local last_process = 0
        local function log_process(process)
            local p = math.floor(process * 10)
            if p ~= last_process then
                log.info(("process: %2f"):format(process))
                last_process = p
            end
        end
        for sampleidx=1, numsample do
            local hx, hy = batcher:step()

            for side=1, 5 do
                local vp, view, proj = bake_ctx:sample_hemisphere(hx, hy, hemisize, side, setting.z_near, setting.z_far, sampleidx)
                render_scene(vp, view, proj, scene_objects)
            end

            local process = sampleidx / numsample
            log_process(process)
        end

        batcher:integrate()
        batcher:write2lightmap(bake_ctx)
    end
end
