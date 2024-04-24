local ecs   = ...
local world = ecs.world
local w     = world.w

local serialize     = import_package "ant.serialize"
local assetmgr      = import_package "ant.asset"
local renderpkg     = import_package "ant.render"
local mathpkg       = import_package "ant.math"
local mu            = mathpkg.util

local layoutmgr     = renderpkg.layoutmgr

local imesh         = ecs.require "ant.asset|mesh"
local iani          = ecs.require "ant.animation|animation"
local icompute      = ecs.require "ant.render|compute.compute"
local irender       = ecs.require "ant.render|render"
local idi           = ecs.require "ant.render|draw_indirect.draw_indirect"
local math3d        = require "math3d"
local bgfx          = require "bgfx"

local r2l_mat <const> = mathpkg.constant.R2L_MAT

local anibaker_sys = ecs.system "animation_baker_system"
function anibaker_sys:entity_remove()
    for e in w:select "REMOVED animation_instances:in" do
        if e.animation_instances.framehandle then
            bgfx.destroy(e.animation_instances.framehandle)
            e.animation_instances.framehandle = nil
        end
    end
end

local iab = {}

--[[
---
data:
  animation: $path animations/animation.ozz
  scene: {}
policy:
  ant.animation|animation
tag:
  animation
---
data:
  material: $path materials/Material.material
  mesh: $path meshes/Mesh_P1.meshbin
  scene: {}
  skinning: 1
  visible: true
  visible_masks: main_view|selectable|cast_shadow
mount: 1
policy:
  ant.animation|skinning
  ant.render|skinrender
tag:
  zi_b_001_01
]]

local function bake_meshes(meshes)
    local checkmat = meshes[1].data.material
    local meshset = imesh.meshset_create
    for _, e in ipairs(meshes) do
        assert(e.data.material == checkmat, "TODO: assume all mesh with same material")
        local m = assetmgr.resource(e.data.mesh)
        imesh.meshset_append(meshset, m)
    end
    
    return meshset
end

local function bake_poses(meshes, animation, numposes)
    
end

local function find_policy(e, policy)
    for _, p in ipairs(e.policy) do
        if p == policy then
            return true
        end
    end
end

local function find_skin_meshes(pc)
    local meshes = {}
    for _, e in ipairs(pc) do
        if find_policy(e, "ant.render|skinrender") then
            meshes[#meshes+1] = e
        end
    end
    return meshes
end

local function create_ani(anie)
    return iani.create(anie.data.animation)
end

local function check_create_animation_obj(pc)
    local anie = pc[1]
    local aniescene = anie.data.scene
    assert(aniescene.t == nil and aniescene.r == nil and aniescene.t == nil)
    assert(find_policy(anie, "ant.animation|animation"))
    return iani.create(anie.data.animation)
end

local function buffer_desc(layout)
    local offset = 0
    local desc = {}
    for l in layout:gmatch "[^|]+" do
        local n = l:sub(1, 1)
        local stride = layoutmgr.elem_size(l)
        desc[n] = {
            offset  = offset,
            stride  = stride,
            num     = l:sub(2, 2) - '0',
            type    = l:sub(6, 6),
            layout  = l,
            load    = function (self, data)
                local start = self.offset+1
                return data:sub(start, start+self.stride)
            end,
        }

        offset = offset + stride
    end

    return desc
end


local meshmt = {
    init = function (self)
        self.desc = buffer_desc(self.meshres.vb.declname)
    end,
    numv = function (self)
        return self.meshres.vb.num
    end,
    load_transform = function(self)
        return self.transform
    end,
    loadvertex = function (self, iv)
        local vertices = self.vertices[iv]
        if iv then
            return vertices[iv]
        end

        local s = layoutmgr.layout_stride(self.meshres.declname)
        local bin = self.meshres.vb.memory[3]
        local start = (iv-1)*s+1
        local v = bin:sub(start, start+s)
        vertices[iv] = v
        return v
    end,
    --iv base0
    loadpos = function(self, iv)
        assert(self.meshres.num >= iv)
        local v = self:loadvertex(iv)

        local posdesc = assert(self.desc.p)
        assert(posdesc.type == 'f')
        local t = posdesc:load(v)
        return math3d.vector(t)
    end,
    loadnormal = function(self, iv)
        assert(self.meshres.num >= iv)
        local v = self:loadvertex(iv)

        local desc = assert(self.desc.n)
        assert(desc.type == 'f')
        local t = desc:load(v)
        return math3d.vector(t)
    end,
    unpack_quat = function (self, iv)
        assert(self.meshres.num > iv)
        local v = self:loadvertex(iv)
        local tangentdesc = assert(self.desc.T)
        assert(tangentdesc.type == 'f')
        return mu.unpack_tangent_frame(math3d.quaternion(tangentdesc:load(v)))
    end,
    loadindices = function (self, iv)
        assert(self.meshres.num >= iv)
        local v = self:loadvertex(iv)
        local indexdesc = assert(self.desc.i)

        local fmt
        if indexdesc.type == "I" then
            fmt = "H"
        elseif indexdesc.type == "u" then
            fmt = "B"
        else
            assert("Invalid index type")
        end

        assert(indexdesc.num == 4)
        local data = indexdesc:load(v)
        local i1, i2, i3, i4 = fmt:rep(4):unpack(data)
        return {i1, i2, i3 ,i4}
    end,
    loadweights = function (self, iv)
        assert(self.meshres.num >= iv)
        local v = self:loadvertex(iv)
        local desc = assert(self.desc.w)
        assert(desc.type == 'f')
        assert(desc.num == 4)

        local data = desc:load(v)
        local f1, f2, f3, f4 = ('f'):rep(4):unpack(data)
        return {f1, f2, f3, f4}
    end,
}

local function is_quat_tbn(meshobj)
    return meshobj.desc.T and meshobj.desc.T.num == 4 and meshobj.desc.n == nil
end

local function build_skinning_matrices(wm, sm)
    local matrices = math3d.array_matrix_ref(sm:pointer(), sm:count())
    local mat = math3d.mul(wm, r2l_mat)
    return math3d.mul_array(mat, matrices)
end

local MAT_ZERO<const> = math3d.constant("mat", {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0})
--return m1 * s + m2
local function scalar_mul_mat4(s, m1, m2)
    local cols = {}
    for ic=1, 4 do
        cols[ic] = math3d.muladd(s, math3d.index(m1, ic), math3d.index(m2, ic))
    end
    return math3d.matrix(cols[1], cols[2], cols[3], cols[4])
end

local function calc_bone_matrix(indices, weights, skinning_matrices)
    local transform = MAT_ZERO
    for ii=1, 4 do
        local idx = indices[ii]
        transform = scalar_mul_mat4(weights[ii], math3d.array_index(skinning_matrices, idx), transform)
    end
    return transform
end

local function bake_animation_mesh(anie, meshobj, num)
    local buffers = {}
    local aniobj = anie.animation

    local quattbn = is_quat_tbn(meshobj)
    
    assert(meshobj.desc.p.num == 3)
    local hasnormal = nil ~= meshobj.desc.n

    local meshset = {}

    local dupilcate_vb2bin
    if meshobj.meshres.vb2 then
        local vb2bin = meshobj.meshres.vb2.memory[1]
        dupilcate_vb2bin = vb2bin:rep(num)
    end

    local skin      = aniobj.skins[meshobj.skinning]
    local wm        = meshobj:load_transform()
    local skinning_matrices = build_skinning_matrices(wm, skin.matrices)
    local numvb     = meshobj:numv()

    for n, status in pairs(aniobj.status) do
        for i=1, num do
            status.ratio = (i-1)/(num-1) --make it layon [0, 1]
            iani.sample(anie)

            -- transform vertices
            local vb = {}
            
            for iv=1, numvb do
                local v = {}

                local indices = meshobj:loadindices(iv)
                local weights = meshobj:loadweights(iv)
                local transform = calc_bone_matrix(indices, weights, skinning_matrices)

                local p = meshobj:loadpos(iv)
                p = math3d.transform(transform, p, 1)
                
                v[#v+1] = math3d.serialize(p):sub(1, 12)
                if quattbn then
                    local normal, tangent = meshobj:unpack_quat(iv)
                    local sign = math3d.index(tangent, 4)
                    normal = math3d.transform(transform, normal, 0)
                    tangent = math3d.transform(transform, tangent, 0)
                    local x, y, z = math3d.index(tangent, 1, 2, 3)
                    tangent = math3d.vector(x, y, z, sign)
                    v[#v+1] = math3d.serialize(mu.pack_tangent_frame(normal, tangent))

                elseif hasnormal then
                    local normal = meshobj:loadnormal(iv)
                    normal = math3d.transform(transform, normal, 0)
                    v[#v+1] = math3d.serialize(normal):sub(1, 12)
                end
                
                vb[#vb+1] = v
            end

            buffers[#buffers+1] = vb
        end

        local newvbbin = table.concat(buffers, "")
        local new_numv = numvb * num
        local newmeshobj = {
            vb = {
                memory  = {newvbbin, 1, #newvbbin},
                start   = 0,
                num     = new_numv,
                declname= meshobj.meshres.vb.declname,
            },
        }

        if dupilcate_vb2bin then
            newmeshobj.vb2 = {
                memory = {dupilcate_vb2bin, 1, #dupilcate_vb2bin},
                start   = 0,
                num     = new_numv,
                declname= meshobj.meshres.vb2.declname,
            }
        end

        newmeshobj.ib = meshobj.meshres.ib
        meshset[n] = newmeshobj
    end

    return meshset
end

local function create_mesh_obj(meshe, transform)
    local o = setmetatable({
        meshres     = assetmgr.resource(meshe.data.mesh),
        skinning    = meshe.data.skinning,
        transform   = transform,
    }, {__index=meshmt})
    o:init()

    return o
end

local append_frame; do
    function append_frame(uint_frames, f)
        local uint = {n=1, 0, 0, 0, 0}
        uint[uint.n] = f
        if uint.n == 4 then
            uint_frames[#uint_frames+1] = ("I"):pack(uint[1]|uint[2]<<8|uint[3]<<16|uint[4]<<24)
            uint.n = 1
        else
            uint.n = uint.n + 1
        end
    end
end

local function pack_buffers(instances)
    local transforms = {}
    local uint_frames = {}
    --avoid #instance < 4
    for _, i in ipairs(instances) do
        local m = math3d.transpose(math3d.matrix(i))
        local c0, c1, c2 = math3d.instance(m)

        transforms[#transforms+1] = ("%s%s%s"):format(math3d.serialize(c0), math3d.serialize(c1), math3d.serialize(c2))

        append_frame(uint_frames, i.frame)
    end

    return table.concat(transforms, ""), table.concat(uint_frames, "")
end

local function update_compute_properties(material, ai, di)
    local mesh = ai.mesh
    material.u_mesh_param        = math3d.vector(mesh.vbnum, mesh.ibnum, mesh.bakenum, di.num)
    material.b_instance_frames   = ai.framehandle
    material.b_indirect_buffer   = di.idb_handle
end

local MAX_INSTANCES<const> = 1024
function iab.create(prefab, instances, bakenum)
    local pc = serialize.load(prefab)

    local anie = {
        animation = check_create_animation_obj(pc),
    }

    local meshe = pc[2]

    local meshobj = create_mesh_obj(meshe, math3d.matrix(meshe.data.scene))
    local meshset = bake_animation_mesh(anie, meshobj, bakenum)

    local instancebuffer, animationframe_buffer = pack_buffers(instances)

    local numinstance = #instances

    local ib = meshobj.meshres.ib
    local ani = {}
    for n, m in pairs(meshset) do
        ani[n] = {
            eid = world:create_entity{
                policy = {
                    "ant.render|simplerender",
                    "ant.render|draw_indirect",
                    "ant.render|animation_instances",
                },
                data = {
                    material        = meshe.data.material,
                    scene           = meshe.data.scene,
                    draw_indirect   = {
                        instance_buffer = {
                            memory  = instancebuffer,
                            flag    = "r",
                            layout  = "t45NIf|t46NIf|t47NIf",    --for matrix3x4
                            num     = numinstance,
                            size    = MAX_INSTANCES,
                        }
                    },
                    mesh_result     = m,
                    animation_instances = {
                        instances   = instances,
                        mesh        = {
                            vbnum   = meshobj.meshres.vb.num,
                            ibnum   = ib and ib.num or 0,
                            bakenum = bakenum,
                        },
                        framehandle = bgfx.create_index_buffer(irender.align_buffer(animationframe_buffer), "dr")
                    },
                    visible         = true,
                }
            },
            compute = world:create_entity{
                policy = {
                    "ant.compute|compute"
                },
                data = {
                    material = "/pkg/ant.resources/materials/animation_dispatch.material",
                    dispatch = {
                        size = {numinstance//64+1, 1, 1},
                    },
                    on_ready = function (e)
                        w:extend(e, "dispatch:in")
                        local re = world:entity(ani[n].eid, "animation_instances:in draw_indirect:in")
                        update_compute_properties(e.dispatch.material, re.animation_instances, re.draw_indirect)
                    end,
                }
            }
        }
    end

    return ani
end

--TODO: it's a heavy operation, will update the full instance buffer and animation framebuffer, need a more light operation
function iab.update_instances(abo, instances)
    local re = world:create(abo.render, "animation_instances:in draw_indirect:in")
    local ce = world:create(abo.compute, "dispatch:in")

    local ai = re.animation_instances
    ai.instances = instances

    local instancebuffer, framebuffer = pack_buffers(instances)
    idi.update_instance_buffer(re, instancebuffer, #instances)

    if ai.framehandle then
        bgfx.destroy(ai.framehandle)
    end

    ai.framehandle = bgfx.create_index_buffer(irender.align_buffer(framebuffer), "dr")

    update_compute_properties(ce.dispatch.material, re.animation_instances, re.draw_indirect)

    icompute.dispatch(ce)
end

return iab