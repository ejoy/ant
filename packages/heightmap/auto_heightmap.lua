local ecs = ...
local world = ecs.world
local w = world.w

local math3d    = require "math3d"
local bgfx      = require "bgfx"
local ltask     = require "ltask"
local image     = require "image"

local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler
local viewidmgr = renderpkg.viewidmgr

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local irender   = ecs.import.interface "ant.render|irender"
local icamera   = ecs.import.interface "ant.camera|icamera"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local ientity   = ecs.import.interface "ant.render|ientity"
local auto_hm_sys = ecs.system "auto_heightmap_system"
local depthmaterial

local unit_pre_tex<const>   = 1  --one texel for 1 meter
local rbsize<const>         = 128
local hrbsize               = rbsize/2

local renderinfo = {
    flags = sampler{
        RT="RT_ON",
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
    },
    
    blitflags = sampler{
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
        BLIT="BLIT_AS_DST|BLIT_READBACK_ON"
    },
    
    init = function (ri)
        ri.auto_hm_viewid = viewidmgr.generate "auto_heightmap"
        ri.fbidx = fbmgr.create(
            {rbidx=fbmgr.create_rb{w=rbsize, h=rbsize, layers=1, flags = ri.flags, format="R32F"}},
            {rbidx=fbmgr.create_rb{w=rbsize, h=rbsize, layers=1, flags = ri.flags, format="D24S8"}})
        bgfx.set_view_clear(ri.auto_hm_viewid, "CD", 0, 1, 0)
        bgfx.set_view_rect(ri.auto_hm_viewid, 0, 0, rbsize, rbsize)
        bgfx.set_view_frame_buffer(ri.auto_hm_viewid, fbmgr.get(ri.fbidx).handle)

        ri.blit_viewid = viewidmgr.generate "blit_hm_viewid"
        ri.blitrb = fbmgr.create_rb{w=rbsize, h=rbsize, layers=1, flags=ri.blitflags, format="R32F"}
    end,
    color_handle = function (ri)
        return fbmgr.get_rb(ri.fbidx, 1).handle
    end,
    read_buffer = function (ri)
        local src_handle = ri:color_handle()
        local dst_handle = fbmgr.get_rb(ri.blitrb).handle
        bgfx.blit(ri.blit_viewid, dst_handle, 0, 0, src_handle)
    
        local m = bgfx.memory_buffer(rbsize * rbsize * 4) -- 4 for sizeof(float)
        local frame_readback = bgfx.read_texture(dst_handle, m)
        bgfx.encoder_end()
        while bgfx.frame() < frame_readback do end
        return m
    end
}

local camera_ref

function auto_hm_sys:init()
    depthmaterial = imaterial.load_res "/pkg/ant.heightmap/assets/depth.material"

    camera_ref = icamera.create{
        frustum = {
            l = -hrbsize,
            r = hrbsize,
            b = -hrbsize,
            t = hrbsize,
            n = 0.01,
            f = 100,
            ortho   = true,
        },
        eyepos  = mc.ZERO_PT,
        viewdir = mc.ZAXIS,
        updir   = mc.YAXIS,
    }

    renderinfo:init()

    local eid = ientity.create_quad_entity({x=0, y=0, w=2, h=2}, "/pkg/ant.resources/materials/texquad.material", "quadtest")
    local e <close> = w:entity(eid)
    imaterial.set_property(e, "s_tex", renderinfo:color_handle())
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

local function write_to_file(filename, buffers, fmt, bw, bh, width, height)
    local numbits = image.get_bits_pre_pixel(fmt)
    local numbytes = numbits // 8
    local pm = bgfx.memory_buffer(width*height*bw*bh*numbytes)
    image.pack_memory(buffers, bw*numbytes, bh, width, height, pm)
    local wsize, hsize = math.tointeger(width*bw), math.tointeger(height*bw)
    local ti = default_tex_info(wsize, hsize, fmt)
    local c = image.encode_image(ti, pm, {type="dds", srgb=false})

    local fslocal = require "filesystem.local"
    local f = fslocal.open(fslocal.path(filename), "wb")
    f:write(c)
    f:close()
end

local function fetch_heightmap_data()
    local items = {}
    local sceneaabb = math3d.aabb()
    for _, eid in world:each "auto_heightmap" do
        local e = world[eid]
        local rc = e._rendercache
        local aabb = rc.aabb
        sceneaabb = math3d.aabb_merge(sceneaabb, aabb)
        items[#items+1] = {
            fx          = depthmaterial.fx,
            material    = depthmaterial.material,
            eid         = eid,
            mesh        = rc.mesh,
        }
    end

    local aabb_min, aabb_max = math3d.array_index(sceneaabb, 1), math3d.array_index(sceneaabb, 2)
    local aabb_len = math3d.sub(aabb_max, aabb_min)
    aabb_min, aabb_max = math3d.tovalue(aabb_min), math3d.tovalue(aabb_max)
    local xlen, ylen, zlen = math3d.index(aabb_len, 1, 2, 3)

    local xnumpass = xlen // rbsize + 1
    local znumpass = zlen // rbsize + 1

    local znear = 0.001
    local zfar = ylen+znear

    local movestep = rbsize*unit_pre_tex
    local xoffset, zoffset = movestep/2, movestep/2
    local ypos = math3d.index(math3d.array_index(sceneaabb, 2), 2)

    local f = icamera.get_frustum(camera_ref)
    f.n, f.f = znear, zfar
    icamera.set_frustum(camera_ref, f)

    local buffers ={}
    for iz=1, znumpass do
        local zpos = (iz-1) * movestep + zoffset + aabb_min[3]
        for ix=1, xnumpass do
            local xpos = (ix-1) * movestep + xoffset + aabb_min[1]
            local camerapos = math3d.vector(xpos, ypos, zpos)
            iom.set_position(camera_ref, camerapos)

            local viewmat, projmat = icamera.calc_viewmat(camera_ref), icamera.calc_projmat(camera_ref)
            bgfx.encoder_begin()
            bgfx.touch(renderinfo.auto_hm_viewid)
            bgfx.set_view_transform(renderinfo.auto_hm_viewid, viewmat, projmat)
            assert(false, "not support render single render_render entity")
            for _, ri in ipairs(items) do
                irender.draw(renderinfo.auto_hm_viewid, ri)
            end

            buffers[#buffers+1] = renderinfo:read_buffer()
        end
    end

    -- do
    --     local bbb = {
    --         bgfx.memory_buffer("f", {1.0, 2.0, 3.0, 4.0}),
    --         bgfx.memory_buffer("f", {5.0, 6.0, 7.0, 8.0}),
    --     }

    --     write_to_file("abc1.dds", bbb, "R32F", 2, 2, 2, 1)
    -- end

    write_to_file("abc.dds", buffers, "R32F", rbsize, rbsize, xnumpass, znumpass)
end

local hm_mb = world:sub {"fetch_heightmap"}
function auto_hm_sys:follow_transform_updated()
    for _ in hm_mb:each() do
        ltask.fork(function ()
            local ServiceBgfxMain = ltask.queryservice "ant.render|bgfx_main"
            ltask.call(ServiceBgfxMain, "pause")
            fetch_heightmap_data()
            ltask.call(ServiceBgfxMain, "continue")
        end)
    end
end