local ecs   = ...
local world = ecs.world
local w     = world.w


local ist   = ecs.import.interface "ant.terrain|ishape_terrain"
local iom   = ecs.import.interface "ant.objcontroller|iobj_motion"

local mathpkg=import_package "ant.math"
local mc    = mathpkg.constant
local math3d= require "math3d"
local fs    = require "filesystem"

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
    U = {
        filename = "/pkg/ant.resources.binary/terrain/roads/O_road.glb|mesh.prefab",
    },
    T = {
        filename = "/pkg/ant.resources.binary/terrain/roads/T_road.glb|mesh.prefab",
    },
    O = {
        filename = "/pkg/ant.resources.binary/terrain/roads/O_road.glb|mesh.prefab",
    },
}


function terrain_road_sys:init()

end

local rotators<const> = {
    math3d.ref(math3d.quaternion{axis=mc.YAXIS, r=math.rad(90)}),
    math3d.ref(math3d.quaternion{axis=mc.YAXIS, r=math.rad(180)}),
    math3d.ref(math3d.quaternion{axis=mc.YAXIS, r=math.rad(270)}),
}

local instance_id = 0
local function instance(rt, parent, iiw, iih, unit)
    local ss = resource_scale*unit
    local s = {ss, ss, ss}
    local t = {(iiw-1+0.5)*unit, 0.0, (iih-1+0.5)*unit} --0.5 for x/z offset from mesh center
    local r = rotators[rt:byte(2, 2)-('0'):byte()]
    local srt = {s = s, r = r, t = t}

    instance_id = instance_id + 1
    local filename = assert(road_resources[rt:sub(1, 1)]).filename
    world:pub {"terrain_road", "road", "create", instance_id, iiw, iih, filename, srt, parent}

    return instance_id
end

function terrain_road_sys:entity_init()
    for e in w:select "INIT shape_terrain:in id:in" do
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
                    field.instance_id = instance(rt, e.id, iiw, iih, unit)
                end
            end
        end
    end
end

local itr = ecs.interface "iterrain_road"

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
    if field.instance_id then
        world:pub {"terrain_road", "road", "remove", field.instance_id}
    end
    field.roadtype = roadtype
    w:sync("id:in", te)
    field.instance_id = instance(roadtype, te.id, iiw, iih, st.unit)
end

function itr.set_road_resource(roadtype, prefabres)
    local rr = road_resources[roadtype:sub(1, 1)]
    if rr == nil then
        error(("invalid roadtype:%s"):format(roadtype))
    end

    if not fs.exists(fs.path(prefabres)) then
        error(("invalid prefab resource file:%s, prefab file is not exist"):format(prefabres))
    end

    rr.filename = prefabres
end