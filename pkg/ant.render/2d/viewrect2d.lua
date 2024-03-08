local ecs = ...
local world = ecs.world
local w = world.w
local ientity   = ecs.require "ant.entity|entity"
local imaterial = ecs.require "ant.render|material"
local assetmgr  = import_package "ant.asset"

local viewrect2d_sys = ecs.system "viewrect2d_system"

local function create_viewrect2d_mesh(vr2d)
    local x0, y0 = vr2d.x, vr2d.y
    local x1, y1 = x0+vr2d.w, y0+vr2d.h

    local c = vr2d.color or 0xffffffff

    local u0, v0, u1, v1
    if vr2d.texrect then
        local tr = vr2d.texrect
        u0, v0 = tr.x, tr.y
        u1, v1 = u0+tr.w, v0+tr.h
    else
        u0, v0 = 0, 0
        u1, v1 = 1, 1
    end

    --TODO: p2 use uint16
    return ientity.create_mesh{"p2|c40niu|t20", {
        x0, y1, c, u0, v1,
        x0, y0, c, u0, v0,
        x1, y1, c, u1, v1,
        x1, y0, c, u1, v0,
    }}
end

function viewrect2d_sys:component_init()
    for e in w:select "INIT texturequad:in viewrect2d?out texturequad_ready?out" do
        if e.texturequad then
            local tex = assetmgr.resource(e.texturequad)
            e.viewrect2d = {
                x=0, y=0, w=tex.texinfo.width, h=tex.texinfo.height
            }
            e.texturequad_ready = true
        end
        assert(e.viewrect2d)
    end

    for e in w:select "INIT viewrect2d:in mesh_result:out" do
        e.mesh_result = create_viewrect2d_mesh(e.viewrect2d)
    end
end

function viewrect2d_sys:entity_ready()
    for e in w:select "texturequad_ready texturequad:in filter_material:in" do
        local tex = assetmgr.resource(e.texturequad)
        imaterial.set_property(e, "s_basecolor", tex.id)
    end
end