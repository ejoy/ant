local ecs = ...
local world = ecs.world

local math3d    = require "math3d"
local bgfx      = require "bgfx"
local ltask     = require "ltask"
local image     = require "image"

local renderpkg = import_package "ant.render"
local fbmgr     = renderpkg.fbmgr
local sampler   = renderpkg.sampler
local viewidmgr = renderpkg.viewidmgr

local irender   = world:interface "ant.render|irender"
local icamera   = world:interface "ant.camera|camera"
local iom       = world:interface "ant.objcontroller|obj_motion"
local imaterial = world:interface "ant.asset|imaterial"
local ientity   = world:interface "ant.render|entity"
local auto_hm_sys = ecs.system "auto_heightmap_system"
local depthmaterial

local unit_pre_tex<const>   = 1  --one texel for 1 meter
local rbsize<const>         = 128
local hrbsize               = rbsize/2

local renderinfo = {
    flags = sampler.sampler_flag{
        RT="RT_ON",
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
    },
    
    blitflags = sampler.sampler_flag{
        MIN="LINEAR",
        MAG="LINEAR",
        U="CLAMP",
        V="CLAMP",
        BLIT="BLIT_READWRITE"
    },
    
    init = function (ri)
        ri.auto_hm_viewid = viewidmgr.generate "auto_heightmap"
        ri.fbidx = fbmgr.create{
            fbmgr.create_rb{w=rbsize, h=rbsize, layers=1, flags = ri.flags, format="R32F"},
            fbmgr.create_rb{w=rbsize, h=rbsize, layers=1, flags = ri.flags, format="D24S8"},
        }
        bgfx.set_view_clear(ri.auto_hm_viewid, "CD", 0, 1, 0)
        bgfx.set_view_rect(ri.auto_hm_viewid, 0, 0, rbsize, rbsize)
        bgfx.set_view_frame_buffer(ri.auto_hm_viewid, fbmgr.get(ri.fbidx).handle)

        ri.blit_viewid = viewidmgr.generate "blit_hm_viewid"
        ri.blitrb = fbmgr.create_rb{w=rbsize, h=rbsize, layers=1, flags=ri.blitflags, format="R32F"}
    end,
    color_handle = function (ri)
        return fbmgr.get_rb(fbmgr.get(ri.fbidx)[1]).handle
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

local camera_eid

function auto_hm_sys:init()
    depthmaterial = imaterial.load "/pkg/ant.heightmap/assets/depth.material"

    camera_eid = icamera.create{
        frustum = {
            l = -hrbsize,
            r = hrbsize,
            b = -hrbsize,
            t = hrbsize,
            n = 0.01,
            f = 100,
            ortho   = true,
        },
        eyepos  = math3d.vector(0, 0, 0, 1),
        viewdir = math3d.vector(0,-1, 0, 0),
        updir   = math3d.vector(0, 0, 1, 0),
    }

    renderinfo:init()

    local eid = ientity.create_quad_entity({x=0, y=0, w=2, h=2}, "/pkg/ant.resources/materials/texquad.material", "quadtest")
    imaterial.set_property(eid, "s_tex", {stage=0, texture={handle=renderinfo:color_handle()}})
    -- local hm_eid = world:create_entity{ 
    --     policy = {
    --         "ant.general|name",
    --         "ant.heightmap|auto_heightmap",
    --     },
    --     data = {
    --         auto_heightmap = {
    --             heightmap_file = "/pkg/ant.heightmap/heightmaps/tmp.heightmap",
    --         },
    --         name = "auto_heightmap_entity",
    --     }
    -- }
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

local function write_to_file(filename, buffers, width, height)
    local pm = bgfx.memory_buffer(width*height*rbsize*rbsize*4)
    image.pack_memory(buffers, rbsize*4, rbsize, width, height, pm)
    local wsize, hsize = math.tointeger(width*rbsize), math.tointeger(height*rbsize)
    local ti = default_tex_info(wsize, hsize, "R32F")
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
            set_transform = function (worldmat)
                bgfx.set_transform(worldmat)
            end,
            fx          = depthmaterial.fx,
            properties  = depthmaterial.properties,
            state       = depthmaterial.state,
            eid         = eid,
            vb          = rc.vb,
            ib          = rc.ib,
        }
    end

    local aabb_min, aabb_max = math3d.index(sceneaabb, 1, 2)
    local aabb_len = math3d.sub(aabb_max, aabb_min)
    aabb_min, aabb_max = math3d.tovalue(aabb_min), math3d.tovalue(aabb_max)
    local xlen, ylen, zlen = math3d.index(aabb_len, 1, 2, 3)

    local xnumpass = xlen // rbsize + 1
    local znumpass = zlen // rbsize + 1

    local znear = 0.001
    local zfar = ylen+znear

    local movestep = rbsize*unit_pre_tex
    local xoffset, zoffset = movestep/2, movestep/2
    local ypos = math3d.index(math3d.index(sceneaabb, 2), 2)

    local f = icamera.get_frustum(camera_eid)
    f.n, f.f = znear, zfar
    icamera.set_frustum(camera_eid, f)

    local buffers ={}
    for iz=1, znumpass do
        local zpos = (iz-1) * movestep + zoffset + aabb_min[3]
        for ix=1, xnumpass do
            local xpos = (ix-1) * movestep + xoffset + aabb_min[1]
            local camerapos = math3d.vector(xpos, ypos, zpos)
            iom.set_position(camera_eid, camerapos)

            local viewmat, projmat = icamera.calc_viewmat(camera_eid), icamera.calc_projmat(camera_eid)
            bgfx.encoder_begin()
            bgfx.touch(renderinfo.auto_hm_viewid)
            bgfx.set_view_transform(renderinfo.auto_hm_viewid, viewmat, projmat)
            for _, ri in ipairs(items) do
                irender.draw(renderinfo.auto_hm_viewid, ri)
            end

            buffers[#buffers+1] = renderinfo:read_buffer()
        end
    end

    write_to_file("abc.dds", buffers, xnumpass, znumpass)
end

local hm_mb = world:sub {"fetch_heightmap"}
function auto_hm_sys:follow_transform_updated()
    for _ in hm_mb:each() do
        ltask.fork(function ()
            local ServiceBgfxMain = ltask.queryservice "bgfx_main"
            ltask.call(ServiceBgfxMain, "pause")
            fetch_heightmap_data()
            ltask.call(ServiceBgfxMain, "continue")
        end)
    end
end