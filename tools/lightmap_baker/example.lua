local ecs = ...
local world = ecs.world
local bgfx = require "bgfx"
local example_sys = ecs.system "lightmap_example"
local ilm = world:interface "ant.bake|ilightmap"
local imaterial = world:interface "ant.asset|imaterial"
local irender = world:interface "ant.render|irender"
local iom = world:interface "ant.objcontroller|obj_motion"
local ientity = world:interface "ant.render|entity"
local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local sampler = renderpkg.sampler

local sample = {
    pos = math3d.ref(math3d.vector(0, 0, 0, 1)),
    dir = math3d.ref(math3d.vector(0, 1, 0, 0)),
    up  = math3d.ref(math3d.vector(0, 0, -1, 0)),
}

local bake = require "bake"

if false then
    local function default_weight()
        return 1.0
    end

    local function gen_hemisphere_weights(hemisize, weight_func)
        weight_func = weight_func or default_weight
        local weights = {}
         local center = (hemisize - 1) * 0.5
         local sum = 0
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
                weights[w0+1] = solidAngle * weight_func(v[3])
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
    
        weights.w, weights.h, weights.c = 3*hemisize, hemisize, 2
        return weights
    end

    local function read_bin(filename)
        local f = io.open(filename, "rb")
        local cc = f:read "a"
        f:close()
        local w, h, c = ("III"):unpack(cc)
        assert(#cc == 12+w*h*c*4)
        local fmt = ("f"):rep(c)

        local pitch = w*c*4

        local v = {
            w=w, h=h, c=c,
            data = cc,
            offset = 12,
        }
        -- for ih=0, h-1 do
        --     local ihoffset = ih * pitch
        --     for iw=0, w-1 do
        --         local offset = ihoffset + iw*c*4 + 12
        --         local t = table.pack(fmt:unpack(cc, offset))
        --         for i=1, c do
        --             v[#v+1] = t[i]
        --         end
        --     end
        -- end
        -- assert(#v == w*h*c)
        return v
    end

    local function sample(fragCoord, hemispheres, weights)
        local function mul(l, r) local v = {} for i=1, #l do v[i] = l[i] * r[i] end return v end
        local function add(l, r) local v = {} for i=1, #l do v[i] = l[i] + r[i] end return v end
        local function vec2(v1, v2) return {v1, v2} end
        local function ivec2(v1, v2)return {math.floor(v1), math.floor(v2)} end
        local function textureSize(tex, level) 
            return {tex.w, tex.h}
        end

        local function fmod(l, m)
            local v = {}
            for i=1, #l do
                v[i] = math.fmod(l[i], m[i])
            end
            return v
        end

        local function floor(l) local v = {} for i=1, #l do v[i] = math.floor(l[i]) end return v end

        local function texelFetch(tex, uv, level)
            local idx = uv[2] * tex.w * tex.c + uv[1] * tex.c
            if tex.offset then
                local fmt = ("f"):rep(tex.c)
                local offset = idx * 4
                local t = table.pack(fmt:unpack(tex.data, offset+tex.offset))
                local v = {}
                for i=1, tex.c do
                    v[i] = t[i]
                end
                return v
            end

            return {tex[idx], tex[idx+1]}
        end

        local function weightedSample(h_uv, w_uv, quadrant)
            local s = texelFetch(hemispheres, add(h_uv, quadrant), 0)
            local w = texelFetch(weights, add(w_uv, quadrant), 0)
            local v = {}
            for i=1, 3 do
                v[i] = s[i] * w[1]
            end
            v[4] = s[4] * w[2]
            --return s.rgb * w.r, s.a * w.g
            return v
        end

        local function threeWeightedSamples(h_uv, w_uv, offset)
            local sum = weightedSample(h_uv, w_uv, offset)
            sum = add(sum, weightedSample(h_uv, w_uv, add(offset, ivec2(2, 0))))
            sum = add(sum, weightedSample(h_uv, w_uv, add(offset, ivec2(4, 0))))
            return sum
        end

        -- this is a weighted sum downsampling pass (alpha component contains the weighted valid sample count)
        local in_uv = add(mul(fragCoord, vec2(6.0, 2.0)), vec2(0.5, 0.5))
        local h_uv = {math.floor(in_uv[1]), math.floor(in_uv[2])}
        local w_uv = floor(fmod(in_uv, textureSize(weights, 0))) -- there's no integer modulo :(
        local lb = threeWeightedSamples(h_uv, w_uv, ivec2(0, 0))
        local rb = threeWeightedSamples(h_uv, w_uv, ivec2(1, 0))
        local lt = threeWeightedSamples(h_uv, w_uv, ivec2(0, 1))
        local rt = threeWeightedSamples(h_uv, w_uv, ivec2(1, 1))
        return add(lb, add(rb, add(lt, rt)))
    end

    local weights = gen_hemisphere_weights(64)
    local dx_hemi = read_bin "d:/work/ant/tools/lightmap_baker/assets/textures/hemispheres/dx.bin"
    local ogl_hemi = read_bin "d:/work/ant/tools/lightmap_baker/assets/textures/hemispheres/ogl.bin"
    local samplewidth, sampleheight = 256, 256
    for ih=0, sampleheight-1 do
        for iw=0, samplewidth-1 do
            local uv = {iw+0.5, ih+0.5}
            local dx_s = sample(uv, dx_hemi, weights)
            local ogl_s = sample(uv, ogl_hemi, weights)

            local function print_sample(name, v)
                print(name)
                local t = {"\t"}
                for i=1, #v do
                    t[#t+1] = v[i]
                    t[#t+1] = ", "
                end
                print(table.concat(t))
            end
            print_sample("dx:", dx_s)
            print_sample("ogl:", ogl_s)
        end
    end
end


local example_eid

local function create_example_mesh()
    local s = 0.3
    local dv, maxuv = 0.49999, 0.99999

	local vb = {
       -s, 0.0, s, 0.0,     0.0,
        s, 0.0, s, maxuv,   0.0,
        s, 0.0,-s, maxuv,   dv,
       -s, 0.0,-s, 0.0,     dv,
       -s, s, 0.0, 0.0,     dv,
        s, s, 0.0, maxuv,   dv,
        s,-s, 0.0, maxuv,   maxuv,
       -s,-s, 0.0, 0.0, 	maxuv,
    }
	
    local ib = {
        0, 3, 2,
        0, 2, 1,

        4, 7, 6,
        4, 6, 5,
    }
	
	return ientity.create_mesh({"p3|t2", vb}, ib)
end

local function face_test()
    local cl = 1
    local ltf = {-cl,  cl,  cl}
    local rtf = { cl,  cl,  cl}
    local rtn = { cl,  cl, -cl}
    local ltn = {-cl,  cl, -cl}
    local lbf = {-cl, -cl,  cl}
    local rbf = { cl, -cl,  cl}
    local rbn = { cl, -cl, -cl}
    local lbn = {-cl, -cl, -cl}

    local du = 1.0/6.0
    local vb = {
        --left:
        lbf[1], lbf[2], lbf[3], 0, 0,
        lbn[1], lbn[2], lbn[3], du,0,
        ltf[1], ltf[2], ltf[3], du,1,
        ltn[1], ltn[2], ltn[3], 0, 1,
        --right
        rtf[1], rtf[2], rtf[3], du, 0,
        rtn[1], rtn[2], rtn[3],2*du,0,
        rbn[1], rbn[2], rbn[3],2*du,1,
        rbf[1], rbf[2], rbf[3], du, 1,

        --top
        ltn[1], ltn[2], ltn[3], 2*du,0,
        rtn[1], rtn[2], rtn[3], 3*du,0,
        rtf[1], rtf[2], rtf[3], 3*du,1,
        ltf[1], ltf[2], ltf[3], 2*du,1,

        --bottom
        lbf[1], lbf[2], lbf[3], 3*du,0,
        rbf[1], rbf[2], rbf[3], 4*du,0,
        rbn[1], rbn[2], rbn[3], 4*du,1,
        lbn[1], lbn[2], lbn[3], 3*du,1,

        --near
        ltf[1], ltf[2], ltf[3], 4*du,0,
        rtf[1], rtf[2], rtf[3], 5*du,0,
        rbf[1], rbf[2], rbf[3], 5*du,1,
        lbf[1], lbf[2], lbf[3], 4*du,1,

        --far
        lbn[1], lbn[2], lbn[3], 5*du,0,
        rbn[1], rbn[2], rbn[3], 6*du,0,
        rtn[1], rtn[2], rtn[3], 6*du,1,
        ltn[1], ltn[2], ltn[3], 5*du,1,
    }

    --face to origin
    local ib = {
        0, 1, 2, 2, 0, 3,
    }

    for i=1, 5 do
        local offset = i*4
        for j=1, 6 do
            ib[#ib+1] = ib[j] + offset
        end
    end

    return ientity.create_mesh({"p3|t2", vb}, ib)
end

function example_sys:init()
    example_eid = world:create_entity {
        policy = {
            "ant.general|name",
            "ant.bake|lightmap",
            "ant.render|render",
        },
        data = {
            scene_entity = true,
            lightmap = {
                size = 16,
                hemisize = 64,
            },
            transform = {},
            --material = "/pkg/ant.tool.lightmap_baker/assets/example/materials/example.material",
            material = "/pkg/ant.tool.lightmap_baker/assets/face_test.material",
            --mesh = "/pkg/ant.tool.lightmap_baker/assets/example/meshes/gazebo.glb|meshes/Node-Mesh_P1.meshbin",
            --mesh = create_example_mesh(),
            mesh = face_test(),
            name = "lightmap_example",
            state = 1,
        }
        
    }

    local e = world[example_eid]
    local rc = e._rendercache
    --rc.simple_mesh = "d:/work/ant/tools/lightmap_baker/assets/example/meshes/gazebo.obj"
    rc.eid = example_eid
    rc.worldmat = e._rendercache.srt

    -- local pf = {
    --     filter_order = {"opaticy"},
    --     result = {
    --         opaticy = {
    --             items = {rc},
    --             visible_set = {rc},
    --         }
    --     }
    -- }
    -- ilm.bake_entity(example_eid, pf, true)

    -- local lm = e._lightmap.data
    -- local lm1 = e.lightmap

    -- local s = lm1.size * lm1.size * 4 * 4
    -- local mem = bgfx.memory_buffer(lm:data(), s, lm)

    -- lm:save "d:/tmp/lresult.tga"

    -- local flags = sampler.sampler_flag {
    --     MIN="LINEAR",
    --     MAG="LINEAR",
    -- }

    -- local lm_handle = bgfx.create_texture2d(lm1.size, lm1.size, false, 1, "RGBA32F", flags, mem)
    -- -- local assetmgr = import_package "ant.asset"
    -- -- local lm_handle = assetmgr.resource "/pkg/ant.lightmap_baker/textures/lm.texture".handle
    -- imaterial.set_property(example_eid, "s_lightmap", {
    --     stage = 0,
    --     texture = {
    --         handle = lm_handle
    --     }
    -- })

    local function render(side)
        local vp, view, proj = bake.set_view(
            0, 0, 64,
            side, 
            0.001, 100,
            sample.pos.p, sample.dir.p, sample.up.p
        )

        local viewid = 40
        bgfx.touch(viewid)
        local rc = world[example_eid]._rendercache
        bgfx.set_view_rect(viewid, vp[1], vp[2], vp[3], vp[4])
        bgfx.set_view_transform(viewid, view, proj)
        irender.draw(viewid, rc)

        bgfx.frame()
    end

    render(0)
    render(1)
    render(2)
    render(3)
    render(4)

    rc.worldmat = nil
    rc.eid = nil
end

function example_sys:post_init()
    local mq = world:singleton_entity "main_queue"
    iom.set_position(mq.camera_eid, math3d.vector(0, 0, -2))
end

local keymb = world:sub{"keyboard"}

function example_sys:data_changed()
    
    for _, key, press, status in keymb:unpack() do
        if key == "SPACE" and press == 0 then

        end
    end
end