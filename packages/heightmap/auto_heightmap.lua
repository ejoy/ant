local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local bgfx = require "bgfx"
local renderpkg = import_package "ant.render"
local fbmgr = renderpkg.fbmgr
local sampler = renderpkg.sampler
local viewid_mgr = renderpkg.viewid_mgr

local irender = world:interface "ant.render|render"
local icamera = world:interface "ant.camera|camera"
local iom = world:interface "ant.objcontroller|obj_motion"

local auto_hm_sys = ecs.system "auto_heightmap_system"

function auto_hm_sys:init()
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

local auto_hm_viewid = viewid_mgr.generate "auto_heightmap"

local unit_pre_tex<const>   = 1  --one texel for 1 meter
local rbsize<const>         = 512
local hrbsize               = rbsize/2

local flags = sampler.sampler_flag{
    RT="RT_ON",
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
}

local fbidx = fbmgr.create{
    fbmgr.create_rb{w=rbsize, h=rbsize, layers=1, flags = flags, format="R32F"},
    fbmgr.create_rb{w=rbsize, h=rbsize, layers=1, flags = flags, format="D24S8"},
}

bgfx.set_view_frame_buffer(auto_hm_viewid, fbmgr.get(fbidx).handle)

local blitflags = sampler.sampler_flag{
    MIN="LINEAR",
    MAG="LINEAR",
    U="CLAMP",
    V="CLAMP",
    BLIT="BLIT_READWRITE"
}

local blit_viewid = viewid_mgr.generate "blit_hm_viewid"
local blitrb = fbmgr.create_rb{w=rbsize, h=rbsize, layers=1, flags=blitflags, format="R32F"}

local function read_back()
    local src_handle = fbmgr.get_rb(fbmgr.get(fbidx)[2]).handle
    local dst_handle = fbmgr.get_rb(blitrb).handle
    bgfx.blit(blit_viewid, 
        src_handle, 0, 0,
        dst_handle, 0, 0, rbsize, rbsize)

    local m = bgfx.memory_buffer("f", rbsize * rbsize * 4) -- 4 for sizeof(float)
    local frame_readback = bgfx.read_texture(dst_handle, m)
    while (bgfx.frame() < frame_readback) do end

    local s = tostring(m)
    local fmt = ('f'):rep(16)   --16 float one time
    local buffer = {}
    for ih=1, rbsize do
        for iw=1, rbsize / #fmt do
            local offset = (ih-1) * rbsize + (iw-1) * #fmt
            local t = {fmt:unpack(s, offset)}
            for i=1, #fmt do
                buffer[offset+i] = t[i]
            end
        end
    end

    return buffer
end

local function write_to_file(filename, buffers, width, height)
    --ppm format for test
    local data = {}
    local wsize = width * rbsize
    local hsize = height * rbsize
    for ih=1, hsize do
        for iw=1, wsize do
            local hoffset = (ih-1)*wsize
            local dataidx = hoffset+iw
            local h = hoffset // rbsize
            local w = iw // rbsize + 1
            local whichbuffer = h * width + w
            local b = buffers[whichbuffer]
            local bidx = iw % rbsize + 1
            data[dataidx] = b[bidx]
        end
    end

    --TODO
end

bgfx.set_view_rect(auto_hm_viewid, 0, 0, rbsize, rbsize)

local hm_mb = world:sub {"fetch_heightmap"}
function auto_hm_sys:data_changed()
    for _ in hm_mb:each() do
        local items = {}
        local sceneaabb = math3d.aabb()
        for _, eid in world:each "auto_heightmap" do
            local e = world[eid]
            local rc = e._rendercache
            local aabb = rc.aabb
            math3d.merge(sceneaabb, aabb)
            items[#items+1] = rc
        end


        local _, extent = math3d.aabb_center_extents(sceneaabb)
        local xlen, ylen, zlen = math3d.index(extent, 1, 2, 3)

        local xnumpass = xlen / rbsize
        if xnumpass * rbsize ~= xlen then
            xnumpass = xnumpass + 1
        end

        local znumpass = zlen / rbsize
        if znumpass * rbsize ~= zlen then
            znumpass = znumpass + 1
        end

        local znear = 0.001
        local zfar = ylen+znear

        local ceid = icamera.create{
            frustum = {
                l = -hrbsize,
                r = hrbsize,
                b = -hrbsize,
                t = rbsize,
                n = znear,
                f = zfar,
            },
            eyepos = {0, 0, 0, 1},
            viewdir = {0, -1, 0, 0},
            updir = {0, 0, 0, 1, 0},
            ortho = true,
        }

        local movestep = rbsize*unit_pre_tex
        local xoffset, zoffset = movestep/2, movestep/2
        local ypos = math3d.index(math3d.index(sceneaabb, 2), 2)

        local buffers ={}
        for iz=1, znumpass do
            local zpos = (iz-1) * movestep + zoffset
            for ix=1, xnumpass do
                local xpos = (ix-1) * movestep + xoffset
                local camerapos = math3d.vector(xpos, ypos, zpos)
                iom.set_position(ceid, camerapos)

                local viewmat, projmat = icamera.calc_viewmat(ceid), icamera.calc_projmat(ceid)
                bgfx.touch(auto_hm_viewid)
                bgfx.set_view_transform(auto_hm_viewid, viewmat, projmat)
                for _, ri in ipairs(items) do
                    irender.draw(ri)
                end

                buffers[#buffers+1] = read_back()
            end
        end

        write_to_file("abc.dds", buffers, xnumpass, znumpass)


        world:remove(ceid)
    end
end