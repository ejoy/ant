local ecs   = ...
local world = ecs.world
local w     = world.w

local mt_sys = ecs.system "mesh_terrain_system"

local function instance(pid, mp, centerpos)
    local root = world:create_entity {
        policy = {
            "ant.scene|scene_object",
        },
        data = {
            scene = {
                parent = pid,
                t = centerpos,
            }
        }
    }
    return world:create_instance {
        prefab = mp,
        parent = root,
    }
end

function mt_sys:entity_init()
    for e in w:select "INIT shape_terrain:in eid:in" do
--[[         local st = e.shape_terrain
        local ms = st.mesh_shape
        local tw, th = st.width, st.height
        local mw, mh = ms.w, ms.h
        local ww, hh = tw // mw, th //mh
        local unit = st.unit
        assert(ww * hh == #ms, "Invalid mesh indices")

        local terrainid = e.eid
        local meshprefabs = ms.meshes
        local instances = {}
        for ih=1, hh do
            local ridx = (ih-1) * ww
            for iw=1, ww do
                local idx = iw+ridx
                local midx = ms[idx]
                local centerpos = {mw * (iw-1+0.5) * unit, 0.0, mh * (ih-1+0.5) * unit}
                instances[idx] = instance(terrainid, assert(meshprefabs[midx]), centerpos)
            end
        end
        ms.instances = instances ]]
    end
end

local ims = {}

function ims.set(e, midx, iw, ih)
    w:extend(e, "shape_terrain:in eid:in")
    local st = e.shape_terrain
    local ms = st.mesh_shape
    local instances = ms.instances
    local idx = iw+(ih-1)*ms.w
    local inst = instances[idx]
    if inst then
        for e in ipairs(inst.tag['*']) do
            world:remove(e)
        end
    end

    instances[idx] = instance(e.eid, ms.meshes[midx])
end

function ims.set_resource(te, idx, prefabres)
    local st = te.shape_terrain
    st.mesh_shape.meshes[idx] = prefabres
end

return ims
