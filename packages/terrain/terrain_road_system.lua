local ecs   = ...
local world = ecs.world
local w     = world.w

local ist   = ecs.import.interface "ant.terrain|ishape_terrain"
local iom   = ecs.import.interface "ant.objcontroller|obj_motion"

local mathpkg=import_package "ant.math"
local mc    = mathpkg.constant
local math3d= require "math3d"
local terrain_road_sys = ecs.system "terrain_road_system"

local resource_scale<const> = 0.1
local road_resources = {
    I = {
        filename = "/pkg/ant.resources.binary/terrain/roads/I_road.glb|mesh.prefab",
    },
    C = {
        filename = "/pkg/ant.resources.binary/terrain/roads/C_road.glb|mesh.prefab",
    },
    X = {
        filename = "/pkg/ant.resources.binary/terrain/roads/X_road.glb|mesh.prefab",
    },
    O = {
        filename = "/pkg/ant.resources.binary/terrain/roads/O_road.glb|mesh.prefab",
    },
    T = {
        filename = "/pkg/ant.resources.binary/terrain/roads/T_road.glb|mesh.prefab",
    }
}


function terrain_road_sys:init()

end

local rotators<const> = {
    math3d.ref(math3d.quaternion{axis=mc.YAXIS, r=math.rad(90)}),
    math3d.ref(math3d.quaternion{axis=mc.YAXIS, r=math.rad(180)}),
    math3d.ref(math3d.quaternion{axis=mc.YAXIS, r=math.rad(270)}),
}

-- local function create_road_entity(srt, parent)
--     return ecs.create_entity{
--         policy = {
--             "ant.terrain|terrain_road",
--             "ant.scene|scene_object",
--             "ant.general|name",
--         },
--         data = {
--             scene = {
--                 srt = assert(srt),
--                 parent = parent,
--             },
--             name = "road_entity",
--             terrain_roads = {},
--             reference = true,
--         }
--     }
-- end

local function instance(rt, parent, iiw, iih, unit)
    local ss = resource_scale*unit
    local s = {ss, ss, ss}
    local t = {(iiw-1+0.5)*unit, 0.0, (iih-1+0.5)*unit} --0.5 for x/z offset from mesh center
    local r = rotators[rt:byte(2, 2)-('0'):byte()]

    local filename = assert(road_resources[rt:sub(1, 1)]).filename

    local p = ecs.create_instance(filename)
    function p.on_ready(prefab)
        local e = prefab.root
        iom.set_srt(e, s, r, t)
        ecs.method.set_parent(e, parent)
    end
    world:create_object(p)
    return p
end

function terrain_road_sys:entity_init()
    for e in w:select "INIT shape_terrain:in reference:in" do
        local st = e.shape_terrain
        local ww, hh = st.width, st.height
        local terrainfileds = st.terrain_fields
        local unit = st.unit

        for iih=1, hh do
            for iiw=1, ww do
                local idx = (iih-1)*ww+iiw
                local field = terrainfileds[idx]
                local rt = field.roadtype
                if rt then
                    field.road = instance(rt, e.reference, iiw, iih, unit)
                end
            end
        end
    end
end

local itr = ecs.interface "iterrain_road"

local function remove_prefab(p)
    if p then
        for _, e in ipairs(p.tag["*"]) do
            w:remove(e)
        end
    end
end

function itr.set_road(te, roadtype, iiw, iih)
    w:sync("shape_terrain:in", te)
    local st = te.shape_terrain
    local ww, hh = st.width, st.height
    if iiw<=0 or iiw>ww  or iih<=0 or iih>hh then
        error(("invalid terrain index:(%d, %d), with terrain size:(%d, %d)"):format(iiw, iih, ww, hh))
    end

    local idx = (iih-1)*ww+iiw
    local terrain_fields = st.terrain_fields
    local field = terrain_fields[idx]
    remove_prefab(field.road)
    field.roadtype = roadtype
    w:sync("reference:in", te)
    field.road = instance(roadtype, te.reference, iiw, iih, st.unit)
end