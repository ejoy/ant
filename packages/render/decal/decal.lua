local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

local imaterial = world:interface "ant.asset|imaterial"
local bgfx = require "bgfx"

local dm = ecs.action "decal_mount"
function dm.init(prefab, idx, value)
    local eid = prefab[idx]
    local e = world[eid]
    local rc = e._rendercache
    rc.decaled_eid = prefab[value]
    local de_rc = world[rc.decaled_eid]._rendercache
    rc.vb = de_rc.vb
    rc.ib = de_rc.ib

    rc.set_transform = function (self)
        bgfx.set_transform(de_rc.worldmat)
    end
end

local dt = ecs.transform "decal_transform"
local function update_decal(e)
    local _rc = e._rendercache
    local decal = e.decal
    local hw, hh = decal.w * 0.5, decal.h * 0.5
    _rc.frustum = {
        l = -hw, r = hw,
        b = -hh, t = hh,
        n = 0, f = 1,
        ortho = true,
    }
end

function dt.process_entity(e)
    update_decal(e)
end

local ds = ecs.system "decal_system"

local decal_register_mb = world:sub{"component_register", "decal"}
local decal_entity_remove_mb = world:sub{"entity_remove", "decal"}

local decal_changed_mb = {}
function ds:data_changed()
    for _, _, eid in decal_register_mb:unpack() do
        decal_changed_mb[eid] = world:sub{"component_changed", "decal", eid}
    end

    for _, _, eid in decal_entity_remove_mb:unpack() do
        decal_changed_mb[eid] = nil
    end

    for eid, mb in pairs(decal_changed_mb) do
        for _, _, eid in mb:unpack() do
            update_decal(world[eid])
        end
    end

	for v in w:select "scene_changed eid:in" do
        local e = world[v.eid]
        if e.decal then
            update_decal(e)
        end
	end

end

-- rotate Z Axis -> Y Axis
local rotateYZ_MAT = math3d.ref(
    math3d.matrix(
        1, 0, 0, 0,
        0, 0, -1, 0,
        0, 1, 0, 0,
        0, 0, 0, 1)
    )

function ds:follow_transform_updated()
    for _, eid in world:each "decal" do
        local de = world[eid]
        local rc = de._rendercache

        local mm = math3d.mul(rotateYZ_MAT, rc.worldmat)

        rc.viewmat = math3d.inverse(mm)
        rc.projmat = math3d.projmat(rc.frustum)
        rc.viewprojmat = math3d.mul(rc.projmat, rc.viewmat)

        imaterial.set_property(eid, "u_decal_mat", math3d.mul(rc.worldmat, rc.viewprojmat))
    end
end