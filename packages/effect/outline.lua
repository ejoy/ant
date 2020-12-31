local ecs = ...
local world = ecs.world

local a_ol = ecs.action "outline"
function a_ol.init(prefab, idx, value)
    local e = world[prefab[idx]]
    local ref_e = world[prefab[value]]

    --ref_e.mesh
end

local ot = ecs.transform "outline_transform"
function ot.process_entity(e)
    e._outline = {}
    for k, v in pairs(e.outline) do
        e._outline[k] = v
    end
end

local iol = ecs.interface "ioutline"
function iol.set_outline(eid, l)
    local e = world[eid]
    local ol = e._outline
    if ol then
        e._outline.width = l.width
        e._outline.color = l.color
    end
end

local ms_ol_sys = ecs.system "meshscale_outline_system"
function ms_ol_sys:data_changed()

end