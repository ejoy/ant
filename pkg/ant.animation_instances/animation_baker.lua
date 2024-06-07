local ecs   = ...
local world = ecs.world
local w     = world.w

local assetmgr      = import_package "ant.asset"
local mathpkg       = import_package "ant.math"
local serialize     = import_package "ant.serialize"
local meshpkg       = import_package "ant.mesh"

local imesh         = ecs.require "ant.asset|mesh"
local iani          = ecs.require "ant.animation|animation"
local math3d        = require "math3d"

local r2l_mat <const> = mathpkg.constant.R2L_MAT

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

local function create_animation_obj(pc)
    local anie = pc[2]
    local function check_animation(e)
        for _, t in ipairs(e.tag) do
            if t == "animation" then
                return true
            end
        end
    end
    assert(check_animation(anie), "Invalid prefab, need animation entity in the first place")
    return {
        animation = iani.create(anie.data.animation)
    }
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

local function calc_bone_matrix(indices, weights, sm)
    local transform = MAT_ZERO
    for ii=1, 4 do
        local idx = indices[ii] --base 0
        transform = scalar_mul_mat4(weights[ii], math3d.array_index(sm, idx+1), transform)
    end
    return transform
end

local function create_new_vb_layout(desc)
    local layout = {desc.p.layout}
    if meshpkg.is_quat_tbn(desc) then
        layout[#layout+1] = desc.T.layout
    elseif desc.n then
        layout[#layout+1] = desc.n.layout
    end

    return table.concat(layout, "|")
end

local function bake_pose(mesho, wm, skin)
    local sm = build_skinning_matrices(wm, skin.matrices)
    -- transform vertices
    local vb = {}
    
    local cp = math3d.checkpoint()
    for iv=1, mesho:numv() do
        local v = {}

        local indices = mesho:loadindices(iv)
        local weights = mesho:loadweights(iv)
        local transform = calc_bone_matrix(indices, weights, sm)
        --- load data
        v[#v+1] = mesho:loadpos(iv, transform)
        
        v[#v+1] = mesho:loadnormal(iv, transform)

        vb[#vb+1] = table.concat(v, "")
    end
    math3d.recover(cp)

    return table.concat(vb, "")
end

local function bake_animation_mesh(anio, mesho, bakenum)
    local aniobj        = anio.animation
    local new_vblayout  = create_new_vb_layout(mesho.desc)

    local meshset = {}

    local dupilcate_vb2bin = mesho.meshres.vb2
    if dupilcate_vb2bin then
        dupilcate_vb2bin = dupilcate_vb2bin.str:rep(bakenum)
    end

    local skin      = aniobj.skins[mesho.skinning.skin]
    local wm        = mesho:load_transform()
    local numvb     = mesho:numv()
	local ib        = mesho.meshres.ib
	if ib then
		-- copy this ib object from resource
		ib = {
			handle  = ib.handle,
			memory  = true,	-- prevent entity delete this handle
			start   = 0,
			num     = ib.num,
			flag    = ib.flag,
		}
	end

    for n, status in pairs(aniobj.status) do
        local buffers = {}
        local lastbakeidx = (bakenum-1)
        for i=0, lastbakeidx do
            status.ratio = i/lastbakeidx
            status.weight = 1.0
            iani.sample(anio)
            buffers[#buffers+1] = bake_pose(mesho, wm, skin)
        end

        local bakestep_ratio = 1/lastbakeidx

        local newvbbin = table.concat(buffers, "")
        local new_numv = numvb * bakenum
        local newmeshobj = {
            vb = {
                memory  = {newvbbin, 1, #newvbbin},
                start   = 0,
                num     = new_numv,
                declname= new_vblayout,
            },
			ib = ib,
        }

        if dupilcate_vb2bin then
            newmeshobj.vb2 = {
                memory = {dupilcate_vb2bin, 1, #dupilcate_vb2bin},
                start   = 0,
                num     = new_numv,
                declname= mesho.meshres.vb2.declname,
            }
        end

        meshset[n] = {
            mesh                = newmeshobj,
            bakestep_ratio      = bakestep_ratio,
            animation_duration  = status.handle:duration(),
        }
    end

    return meshset
end

local function find_policy(e, policy)
    for _, p in ipairs(e.policy) do
        if p == policy then
            return true
        end
    end
end

local function create_mesh_obj(pc)
    --TODO: bake mesh if mesh entity more than two
    assert(#pc == 3)
    local meshe = pc[3]
    assert(find_policy(meshe, "ant.render|skinrender") and meshe.data.mesh and meshe.data.skinning)

    local o = meshpkg.create(assetmgr.resource(meshe.data.mesh), math3d.matrix(meshe.data.scene))
    o.skinning    = meshe.data.skinning
    o.scene       = meshe.data.scene
    o.material    = meshe.data.material
    return o
end


return {
    init = function (prefab)
        local pc = serialize.load(prefab)
        return create_animation_obj(pc), create_mesh_obj(pc)
    end,
    bake = bake_animation_mesh,
}